package com.example.the_guardian_v1.dto.auth;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class KycResponse {
    public enum Status {
        APPROVED, REJECTED
    }

    private Status status;
    private double confidence;
    private String reason;
}
