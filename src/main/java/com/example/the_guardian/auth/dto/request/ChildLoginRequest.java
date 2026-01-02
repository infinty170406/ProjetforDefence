package com.example.the_guardian.auth.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ChildLoginRequest {

    @NotBlank(message = "Child ID is required")
    private String childId;

    @NotBlank(message = "Device ID is required")
    private String deviceId;
}
