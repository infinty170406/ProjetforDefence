package com.example.the_guardian_v1.domain.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

/**
 * Tracks the LAST KNOWN inside/outside state of a (child, geofence) pair.
 * Used to detect ENTER / EXIT transitions.
 */
@Entity
@Table(name = "child_geofence_states", uniqueConstraints = @UniqueConstraint(name = "uq_child_geofence", columnNames = {
        "childId", "geofenceId" }))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ChildGeofenceState {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 36)
    private String childId;

    @Column(nullable = false)
    private Long geofenceId;

    /** true = child is currently inside the geofence. */
    @Column(nullable = false)
    private Boolean insideFence;

    @Column(nullable = false)
    private Instant updatedAt;

    @PrePersist
    @PreUpdate
    void touch() {
        updatedAt = Instant.now();
    }
}
