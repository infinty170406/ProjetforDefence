package com.example.the_guardian_v1.dto.execute;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class CreateChildParams {
    @NotBlank(message = "Name is required")
    public String name;

    @NotNull(message = "Age is required")
    public Integer age;
}
