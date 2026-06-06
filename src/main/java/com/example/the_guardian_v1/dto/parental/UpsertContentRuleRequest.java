package com.example.the_guardian_v1.dto.parental;
import jakarta.validation.constraints.NotBlank;
public class UpsertContentRuleRequest {
  @NotBlank public String action;
  public Double confidenceThreshold;
  public Boolean enabled = true;
}
