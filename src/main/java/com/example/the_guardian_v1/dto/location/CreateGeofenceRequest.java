package com.example.the_guardian_v1.dto.location;

import jakarta.validation.constraints.*;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreateGeofenceRequest {

    @NotBlank(message = "name is required")
    @Size(max = 120, message = "name must be <= 120 characters")
    private String name;

    /** Null = applies to all children of the requesting parent. */
    @Size(min = 36, max = 36, message = "childId must be a valid UUID if provided")
    private String childId;

    @NotNull(message = "centerLatitude is required")
    @DecimalMin(value = "-90.0", inclusive = true)
    @DecimalMax(value = "90.0", inclusive = true)
    private Double centerLatitude;

    @NotNull(message = "centerLongitude is required")
    @DecimalMin(value = "-180.0", inclusive = true)
    @DecimalMax(value = "180.0", inclusive = true)
    private Double centerLongitude;

    @NotNull(message = "radiusMeters is required")
    @DecimalMin(value = "10.0", inclusive = true, message = "radius must be >= 10 m")
    @DecimalMax(value = "50000.0", inclusive = true, message = "radius must be <= 50 km")
    private Double radiusMeters;
}
