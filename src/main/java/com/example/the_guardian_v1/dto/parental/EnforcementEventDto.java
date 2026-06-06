package com.example.the_guardian_v1.dto.parental;

import lombok.Data;

@Data
public class EnforcementEventDto {
    private String eventId;
    private String childId;
    private String type;
    private String actor;
    private String occurredAt;
    private String payloadJson;
    private String createdAt;
}
