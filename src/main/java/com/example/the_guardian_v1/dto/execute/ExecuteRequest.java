package com.example.the_guardian_v1.dto.execute;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
public class ExecuteRequest {
  @NotBlank public String requestId;
  @NotBlank public String childId;
  @NotBlank public String intent;
  @NotNull public Object parameters;
  public String source = "N8N";
  public String timestamp;
}
