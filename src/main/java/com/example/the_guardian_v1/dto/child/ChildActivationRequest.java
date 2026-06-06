package com.example.the_guardian_v1.dto.child;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class ChildActivationRequest {
    @NotBlank
    public String token;
}
