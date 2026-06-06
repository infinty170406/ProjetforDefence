package com.example.the_guardian_v1.dto.ai;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class AiCommandRequest {
    @NotBlank(message = "Prompt is required")
    private String prompt;
    @NotBlank(message = "Child ID is required")
    private String childId;
}
