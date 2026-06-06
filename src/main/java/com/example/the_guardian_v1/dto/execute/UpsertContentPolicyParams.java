package com.example.the_guardian_v1.dto.execute;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
public class UpsertContentPolicyParams {
  @NotBlank public String category;
  @NotBlank public String action;
  public Boolean enabled = true;
  public Double confidenceThreshold;
  public List<String> keywords;
  public String keywordMatch;
  public String locale;
}
