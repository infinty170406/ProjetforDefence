package com.example.the_guardian_v1.controller;

import com.example.the_guardian_v1.dto.auth.*;
import com.example.the_guardian_v1.service.IAuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
@Tag(name = "Authentication", description = "Endpoints for parent authentication and OTP")
public class AuthController {
  private final IAuthService authService;

  public AuthController(IAuthService authService) {
    this.authService = authService;
  }

  @PostMapping(value = "/kyc/verify", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  @Operation(summary = "Identity Verification (KYC)", description = "Submit identity information and images for verification.")
  @ApiResponses(value = {
      @ApiResponse(responseCode = "200", description = "KYC processed successfully", content = @Content(schema = @Schema(implementation = KycResponse.class))),
      @ApiResponse(responseCode = "400", description = "Invalid KYC data")
  })
  public KycResponse verifyKyc(@Valid @ModelAttribute KycSubmissionRequest request) {
    return authService.verifyKyc(request);
  }

  @PostMapping("/otp/send")
  @Operation(summary = "Send OTP", description = "Generates and sends an OTP to the user's email.")
  public void sendOtp(@RequestParam String email) {
    authService.sendOtp(email);
  }

  @PostMapping("/otp/verify")
  @Operation(summary = "Verify OTP", description = "Verifies the OTP provided by the user.")
  public VerifyOtpResponse verifyOtp(@Valid @RequestBody VerifyOtpRequest request) {
    return authService.verifyOtp(request);
  }
}
