package com.example.the_guardian_v1.dto.parent;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class CreateChildRequest {
    @NotBlank
    public String displayName;

    @NotNull
    public Integer age;
}
