package com.example.the_guardian_v1.dto.location;

import jakarta.validation.constraints.*;
import lombok.*;

import java.time.Instant;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LocationUpdateRequest {

    @NotBlank(message = "childId is required")
    @Size(min = 36, max = 36, message = "childId must be a valid UUID")
    private String childId;

    @NotNull(message = "latitude is required")
    @DecimalMin(value = "-90.0", inclusive = true, message = "latitude must be >= -90")
    @DecimalMax(value = "90.0", inclusive = true, message = "latitude must be <= 90")
    private Double latitude;

    @NotNull(message = "longitude is required")
    @DecimalMin(value = "-180.0", inclusive = true, message = "longitude must be >= -180")
    @DecimalMax(value = "180.0", inclusive = true, message = "longitude must be <= 180")
    private Double longitude;

    /** Accuracy reported by the device in metres (optional). */
    @DecimalMin(value = "0.0", message = "accuracy must be non-negative")
    private Float accuracyMeters;

    /** Speed in m/s reported by the device (optional). */
    @DecimalMin(value = "0.0", message = "speed must be non-negative")
    private Float speedMps;

    /**
     * Epoch millis when the position was captured on-device.
     * If null, server time is used.
     */
    private Instant capturedAt;
}
