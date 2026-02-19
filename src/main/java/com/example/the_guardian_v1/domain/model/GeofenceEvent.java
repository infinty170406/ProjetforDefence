package com.example.the_guardian_v1.domain.model;

import com.example.the_guardian_v1.domain.enums.GeofenceTransition;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * Records every ENTER / EXIT geofence crossing detected for a child.
 */
@Entity
@Table(name = "geofence_events", indexes = {
        @Index(name = "idx_gfe_child_time", columnList = "childId, occurredAt DESC"),
        @Index(name = "idx_gfe_geofence_time", columnList = "geofenceId, occurredAt DESC")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GeofenceEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 36)
    private String childId;

    @Column(nullable = false, length = 36)
    private String parentId;

    @Column(nullable = false)
    private Long geofenceId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private GeofenceTransition transition; // ENTER | EXIT

    /** Exact coordinates that triggered the event. */
    @Column(nullable = false, precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(nullable = false, precision = 10, scale = 7)
    private BigDecimal longitude;

    @Column(nullable = false)
    private Instant occurredAt;
}
