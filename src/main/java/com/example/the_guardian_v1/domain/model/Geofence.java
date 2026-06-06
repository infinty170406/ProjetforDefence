package com.example.the_guardian_v1.domain.model;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * A circular geofence defined by a centre point and a radius in metres.
 * Owned by a parent and optionally scoped to a single child.
 */
@Entity
@Table(name = "geofences", indexes = {
        @Index(name = "idx_gf_parent", columnList = "parentId"),
        @Index(name = "idx_gf_child", columnList = "childId")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Geofence {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 36)
    private String parentId;

    /** Null = applies to every child of this parent. */
    @Column(length = 36)
    private String childId;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(nullable = false, precision = 10, scale = 7)
    private BigDecimal centerLatitude;

    @Column(nullable = false, precision = 10, scale = 7)
    private BigDecimal centerLongitude;

    /** Radius in metres. */
    @Column(nullable = false)
    private Double radiusMeters;

    @Builder.Default
    @Column(nullable = false, columnDefinition = "boolean default true")
    private Boolean active = true;

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant updatedAt;

    @PrePersist
    void prePersist() {
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }
}
