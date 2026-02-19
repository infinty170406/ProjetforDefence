package com.example.the_guardian_v1.service.location;

import com.example.the_guardian_v1.common.exception.ForbiddenException;
import com.example.the_guardian_v1.common.exception.NotFoundException;
import com.example.the_guardian_v1.domain.model.Geofence;
import com.example.the_guardian_v1.dto.location.CreateGeofenceRequest;
import com.example.the_guardian_v1.dto.location.GeofenceDto;
import com.example.the_guardian_v1.repository.GeofenceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class GeofenceService {

    private final GeofenceRepository geofenceRepo;

    // ─── Create ────────────────────────────────────────────────────────────────

    @Transactional
    public GeofenceDto create(String parentId, CreateGeofenceRequest req) {
        Geofence fence = Geofence.builder()
                .parentId(parentId)
                .childId(req.getChildId())
                .name(req.getName())
                .centerLatitude(BigDecimal.valueOf(req.getCenterLatitude()))
                .centerLongitude(BigDecimal.valueOf(req.getCenterLongitude()))
                .radiusMeters(req.getRadiusMeters())
                .active(true)
                .build();
        return toDto(geofenceRepo.save(fence));
    }

    // ─── Read ──────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<GeofenceDto> listByParent(String parentId) {
        return geofenceRepo.findByParentIdAndActiveTrue(parentId)
                .stream()
                .map(this::toDto)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public GeofenceDto getById(String parentId, Long geofenceId) {
        Geofence fence = findOwned(parentId, geofenceId);
        return toDto(fence);
    }

    // ─── Toggle active/inactive ────────────────────────────────────────────────

    @Transactional
    public GeofenceDto setActive(String parentId, Long geofenceId, boolean active) {
        Geofence fence = findOwned(parentId, geofenceId);
        fence.setActive(active);
        return toDto(geofenceRepo.save(fence));
    }

    // ─── Delete ────────────────────────────────────────────────────────────────

    @Transactional
    public void delete(String parentId, Long geofenceId) {
        Geofence fence = findOwned(parentId, geofenceId);
        geofenceRepo.delete(fence);
    }

    // ─── Helpers ───────────────────────────────────────────────────────────────

    private Geofence findOwned(String parentId, Long geofenceId) {
        Geofence fence = geofenceRepo.findById(geofenceId)
                .orElseThrow(() -> new NotFoundException("Geofence not found: " + geofenceId));
        if (!fence.getParentId().equals(parentId)) {
            throw new ForbiddenException("You do not own geofence " + geofenceId);
        }
        return fence;
    }

    private GeofenceDto toDto(Geofence f) {
        return GeofenceDto.builder()
                .id(f.getId())
                .parentId(f.getParentId())
                .childId(f.getChildId())
                .name(f.getName())
                .centerLatitude(f.getCenterLatitude().doubleValue())
                .centerLongitude(f.getCenterLongitude().doubleValue())
                .radiusMeters(f.getRadiusMeters())
                .active(f.getActive())
                .createdAt(f.getCreatedAt())
                .updatedAt(f.getUpdatedAt())
                .build();
    }
}
