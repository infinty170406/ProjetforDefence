package com.example.the_guardian_v1.dto.execute;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
public class UpdateProfileParams {
  @NotNull public Boolean enabled;
  @NotBlank public String mode;
  public String timezone;
}
