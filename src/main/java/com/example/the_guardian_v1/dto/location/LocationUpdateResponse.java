package com.example.the_guardian_v1.dto.location;

import lombok.*;

import java.time.Instant;
import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LocationUpdateResponse {

    private String childId;
    private Instant receivedAt;
    private List<String> triggeredGeofenceEvents; // e.g. ["ENTER:Home Zone", "EXIT:School"]
}
