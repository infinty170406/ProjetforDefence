package com.example.the_guardian_v1.service.location;

import org.springframework.stereotype.Component;

/**
 * Haversine formula: calculates the great-circle distance between two
 * geo-coordinates (decimal degrees) and returns the result in metres.
 */
@Component
public class HaversineUtil {

    private static final double EARTH_RADIUS_METERS = 6_371_000.0;

    /**
     * @param lat1 latitude of point A (degrees)
     * @param lon1 longitude of point A (degrees)
     * @param lat2 latitude of point B (degrees)
     * @param lon2 longitude of point B (degrees)
     * @return distance in metres
     */
    public double distanceMeters(double lat1, double lon1,
            double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);

        double sinLat = Math.sin(dLat / 2);
        double sinLon = Math.sin(dLon / 2);

        double a = sinLat * sinLat
                + Math.cos(Math.toRadians(lat1))
                        * Math.cos(Math.toRadians(lat2))
                        * sinLon * sinLon;

        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return EARTH_RADIUS_METERS * c;
    }

    /**
     * Returns true when the given point is inside (or on the boundary of)
     * the circular geofence defined by (centerLat, centerLon, radiusMeters).
     */
    public boolean isInsideFence(double pointLat, double pointLon,
            double centerLat, double centerLon,
            double radiusMeters) {
        return distanceMeters(pointLat, pointLon, centerLat, centerLon) <= radiusMeters;
    }
}
