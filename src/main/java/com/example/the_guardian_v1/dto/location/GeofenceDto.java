package com.example.the_guardian_v1.dto.location;

import lombok.*;

import java.time.Instant;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GeofenceDto {

    private Long id;
    private String parentId;
    private String childId;
    private String name;
    private Double centerLatitude;
    private Double centerLongitude;
    private Double radiusMeters;
    private Boolean active;
    private Instant createdAt;
    private Instant updatedAt;
}
