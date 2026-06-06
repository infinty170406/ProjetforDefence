package com.example.the_guardian_v1.dto.parental;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
public class UpdateParentalProfileRequest {
  @NotNull public Boolean enabled;
  @NotBlank public String mode;
  public String timezone;
}
