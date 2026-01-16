package com.example.the_guardian_v1.dto.execute;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
public class ExecuteRequest {
  public String source = "N8N";
  public String timestamp;
}
