package com.example.the_guardian_v1.service.location;

import com.example.the_guardian_v1.common.exception.ForbiddenException;
import com.example.the_guardian_v1.common.exception.NotFoundException;
import com.example.the_guardian_v1.domain.enums.GeofenceTransition;
import com.example.the_guardian_v1.domain.model.*;
import com.example.the_guardian_v1.dto.location.GeofenceAlertMessage;
import com.example.the_guardian_v1.dto.location.LocationUpdateRequest;
import com.example.the_guardian_v1.dto.location.LocationUpdateResponse;
import com.example.the_guardian_v1.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Orchestrates:
 * 1. Ownership verification (JWT parentId → Child.parentId)
 * 2. Rate limiting via Redis
 * 3. Persisting the LocationSnapshot
 * 4. Geofence evaluation → ENTER/EXIT detection → WebSocket push
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class LocationService {

    @Value("${guardian.location.max-requests-per-minute:30}")
    private int maxRequestsPerMinute;

    private final LocationSnapshotRepository snapshotRepo;
    private final GeofenceRepository geofenceRepo;
    private final GeofenceEventRepository eventRepo;
    private final ChildGeofenceStateRepository stateRepo;
    private final RedisLocationCache cache;
    private final HaversineUtil haversine;
    private final NotificationPublisher notificationPublisher;

    // We need the Child repository to verify ownership.
    private final com.example.the_guardian_v1.repository.ChildRepository childRepo;

    @Transactional
    public LocationUpdateResponse processUpdate(String authenticatedParentId,
            LocationUpdateRequest req) {
        // 1 ─ Ownership verification
        Child child = childRepo.findById(req.getChildId())
                .orElseThrow(() -> new NotFoundException("Child not found: " + req.getChildId()));

        if (!child.getParentId().equals(authenticatedParentId)) {
            throw new ForbiddenException("You do not own child " + req.getChildId());
        }

        // 2 ─ Rate limiting (60-second sliding window via Redis)
        long count = cache.incrementRateCounter(req.getChildId());
        if (count > maxRequestsPerMinute) {
            log.warn("Rate limit exceeded for child {}: {} req/min", req.getChildId(), count);
            throw new com.example.the_guardian_v1.common.exception.ValidationException(
                    "Rate limit exceeded. Max " + maxRequestsPerMinute + " updates/minute.");
        }

        // 3 ─ Persist snapshot
        Instant capturedAt = req.getCapturedAt() != null ? req.getCapturedAt() : Instant.now();
        LocationSnapshot snapshot = LocationSnapshot.builder()
                .childId(req.getChildId())
                .latitude(BigDecimal.valueOf(req.getLatitude()))
                .longitude(BigDecimal.valueOf(req.getLongitude()))
                .accuracyMeters(req.getAccuracyMeters())
                .speedMps(req.getSpeedMps())
                .capturedAt(capturedAt)
                .build();
        snapshotRepo.save(snapshot);

        // 4 ─ Cache latest location
        cache.cacheLastLocation(req.getChildId(), req.getLatitude(), req.getLongitude());

        // 5 ─ Evaluate geofences
        List<String> triggeredEvents = evaluateGeofences(
                child, authenticatedParentId,
                req.getLatitude(), req.getLongitude(), capturedAt);

        // 6 ─ Update child last-seen
        child.setLastSeenAt(Instant.now());

        return LocationUpdateResponse.builder()
                .childId(req.getChildId())
                .receivedAt(Instant.now())
                .triggeredGeofenceEvents(triggeredEvents)
                .build();
    }

    // ─── Geofence Evaluation ───────────────────────────────────────────────────

    private List<String> evaluateGeofences(Child child, String parentId,
            double lat, double lon,
            Instant occurredAt) {
        List<String> triggered = new ArrayList<>();

        // Fetch all active fences for this child (own + parent-wide)
        List<Geofence> fences = geofenceRepo
                .findByParentIdAndActiveTrueAndChildIdIsNullOrParentIdAndActiveTrueAndChildId(
                        parentId, parentId, child.getId());

        for (Geofence fence : fences) {
            boolean nowInside = haversine.isInsideFence(
                    lat, lon,
                    fence.getCenterLatitude().doubleValue(),
                    fence.getCenterLongitude().doubleValue(),
                    fence.getRadiusMeters());

            // Determine previous state (Redis first, then DB, then assume outside)
            boolean wasInside = resolvePreviousState(child.getId(), fence.getId());

            GeofenceTransition transition = detectTransition(wasInside, nowInside);
            if (transition == null)
                continue; // no state change

            // Persist the event
            GeofenceEvent gfEvent = GeofenceEvent.builder()
                    .childId(child.getId())
                    .parentId(parentId)
                    .geofenceId(fence.getId())
                    .transition(transition)
                    .latitude(BigDecimal.valueOf(lat))
                    .longitude(BigDecimal.valueOf(lon))
                    .occurredAt(occurredAt)
                    .build();
            eventRepo.save(gfEvent);

            // Update persistent + cached state
            updateState(child.getId(), fence.getId(), nowInside);

            // Push WebSocket alert
            GeofenceAlertMessage alert = GeofenceAlertMessage.builder()
                    .childId(child.getId())
                    .childName(child.getDisplayName())
                    .parentId(parentId)
                    .geofenceId(fence.getId())
                    .geofenceName(fence.getName())
                    .transition(transition)
                    .latitude(lat)
                    .longitude(lon)
                    .occurredAt(occurredAt)
                    .build();
            notificationPublisher.pushGeofenceAlert(alert);

            triggered.add(transition.name() + ":" + fence.getName());
            log.info("Geofence transition {} child={} fence={}", transition, child.getId(), fence.getName());
        }

        return triggered;
    }

    /**
     * Resolve previous state: Redis cache → DB → default false (outside).
     */
    private boolean resolvePreviousState(String childId, Long geofenceId) {
        Optional<Boolean> cached = cache.getGeofenceState(childId, geofenceId);
        if (cached.isPresent())
            return cached.get();

        return stateRepo.findByChildIdAndGeofenceId(childId, geofenceId)
                .map(ChildGeofenceState::getInsideFence)
                .orElse(false);
    }

    /**
     * Returns ENTER, EXIT, or null (no transition).
     */
    private GeofenceTransition detectTransition(boolean wasInside, boolean nowInside) {
        if (!wasInside && nowInside)
            return GeofenceTransition.ENTER;
        if (wasInside && !nowInside)
            return GeofenceTransition.EXIT;
        return null;
    }

    private void updateState(String childId, Long geofenceId, boolean inside) {
        ChildGeofenceState state = stateRepo
                .findByChildIdAndGeofenceId(childId, geofenceId)
                .orElseGet(() -> ChildGeofenceState.builder()
                        .childId(childId)
                        .geofenceId(geofenceId)
                        .build());
        state.setInsideFence(inside);
        stateRepo.save(state);
        cache.cacheGeofenceState(childId, geofenceId, inside);
    }
}
