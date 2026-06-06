package com.example.the_guardian_v1.service.location;

import com.example.the_guardian_v1.dto.location.LocationUpdateRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Optional;

/**
 * Redis-backed cache for:
 * 1. Rate limiting: track request count per child within a rolling window.
 * 2. Last-known location: avoids DB read for the most recent snapshot.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RedisLocationCache {

    private static final String RATE_KEY_PREFIX = "loc:rate:";
    private static final String LAST_LOC_KEY_PREFIX = "loc:last:";
    private static final Duration RATE_WINDOW = Duration.ofSeconds(60);
    private static final Duration LOCATION_TTL = Duration.ofMinutes(10);

    private final RedisTemplate<String, Object> redisTemplate;

    // ─── Rate Limiting ─────────────────────────────────────────────────────────

    /**
     * Increments the request counter for a child.
     * 
     * @return the NEW count after increment.
     */
    public long incrementRateCounter(String childId) {
        String key = RATE_KEY_PREFIX + childId;
        Long count = redisTemplate.opsForValue().increment(key);
        if (count != null && count == 1) {
            redisTemplate.expire(key, RATE_WINDOW);
        }
        return count != null ? count : 1;
    }

    // ─── Last Location ──────────────────────────────────────────────────────────

    public void cacheLastLocation(String childId, double latitude, double longitude) {
        String key = LAST_LOC_KEY_PREFIX + childId;
        // Store as "lat,lon" string – compact and serializer-agnostic.
        redisTemplate.opsForValue().set(key, latitude + "," + longitude, LOCATION_TTL);
    }

    public Optional<double[]> getLastLocation(String childId) {
        String key = LAST_LOC_KEY_PREFIX + childId;
        Object value = redisTemplate.opsForValue().get(key);
        if (value == null)
            return Optional.empty();
        try {
            String[] parts = value.toString().split(",");
            return Optional.of(new double[] {
                    Double.parseDouble(parts[0]),
                    Double.parseDouble(parts[1])
            });
        } catch (Exception ex) {
            log.warn("Malformed cached location for child {}: {}", childId, value);
            return Optional.empty();
        }
    }

    // ─── Geofence State Cache ───────────────────────────────────────────────────

    private static final String GF_STATE_PREFIX = "gf:state:";
    private static final Duration GF_STATE_TTL = Duration.ofHours(1);

    public void cacheGeofenceState(String childId, Long geofenceId, boolean inside) {
        String key = GF_STATE_PREFIX + childId + ":" + geofenceId;
        redisTemplate.opsForValue().set(key, inside ? "1" : "0", GF_STATE_TTL);
    }

    /**
     * Returns the cached inside/outside state or empty if unknown (first run).
     */
    public Optional<Boolean> getGeofenceState(String childId, Long geofenceId) {
        String key = GF_STATE_PREFIX + childId + ":" + geofenceId;
        Object value = redisTemplate.opsForValue().get(key);
        if (value == null)
            return Optional.empty();
        return Optional.of("1".equals(value.toString()));
    }
}
