package com.example.the_guardian_v1.dto.location;

import lombok.*;
import java.time.Instant;

/**
 * Payload for generic system alerts (screen time, app rules, etc.)
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificationMessage {
    private String title;
    private String message;
    private String type; // e.g., SCREEN_TIME, APP_BLOCK, SECURITY
    private String childId;
    private String parentId;
    private Instant occurredAt;
}
