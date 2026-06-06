package com.example.the_guardian_v1.domain.model;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "location_snapshots", indexes = {
        @Index(name = "idx_loc_child_time", columnList = "childId, capturedAt DESC"),
        @Index(name = "idx_loc_child_id", columnList = "childId")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LocationSnapshot {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 36)
    private String childId;

    @Column(nullable = false, precision = 10, scale = 7)
    private BigDecimal latitude;

    @Column(nullable = false, precision = 10, scale = 7)
    private BigDecimal longitude;

    /** Accuracy in metres as reported by the device. */
    @Column
    private Float accuracyMeters;

    /** Speed in m/s as reported by the device. */
    @Column
    private Float speedMps;

    /** Epoch millis at which the position was recorded on-device. */
    @Column(nullable = false)
    private Instant capturedAt;

    /** Epoch millis when the server received this record. */
    @Column(nullable = false, updatable = false)
    private Instant receivedAt;

    @PrePersist
    void prePersist() {
        if (receivedAt == null)
            receivedAt = Instant.now();
    }
}
