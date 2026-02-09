package com.example.the_guardian_v1.dto.parent;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class LinkChildRequest {
    @NotBlank
    public String childId;
}
