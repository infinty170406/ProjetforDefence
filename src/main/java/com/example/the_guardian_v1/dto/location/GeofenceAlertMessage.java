package com.example.the_guardian_v1.dto.location;

import com.example.the_guardian_v1.domain.enums.GeofenceTransition;
import lombok.*;

import java.time.Instant;

/**
 * Payload pushed over WebSocket to the parent's dedicated topic when a
 * geofence transition occurs.
 *
 * Topic: /topic/alerts/{parentId}
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GeofenceAlertMessage {

    private String childId;
    private String childName; // resolved by service for UX convenience
    private String parentId;
    private Long geofenceId;
    private String geofenceName;
    private GeofenceTransition transition; // ENTER | EXIT
    private Double latitude;
    private Double longitude;
    private Instant occurredAt;
}
