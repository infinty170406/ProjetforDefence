package com.example.the_guardian_v1.dto.auth;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
public class LoginRequest {
  @Email @NotBlank public String email;
  @NotBlank public String password;
}
