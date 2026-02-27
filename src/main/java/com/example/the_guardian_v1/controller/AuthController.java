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
@Tag(name = "Authentication", description = "Endpoints pour l'authentification des parents")
public class AuthController {
  private final IAuthService authService;

  public AuthController(IAuthService authService) {
    this.authService = authService;
  }

  @PostMapping(value = "/kyc/verify", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  @Operation(summary = "Vérification d'identité (KYC)", description = "Soumet les informations d'identité et les images pour vérification.")
  @ApiResponses(value = {
      @ApiResponse(responseCode = "200", description = "KYC traité avec succès", content = @Content(schema = @Schema(implementation = KycResponse.class))),
      @ApiResponse(responseCode = "400", description = "Données KYC invalides")
  })
  public KycResponse verifyKyc(@Valid @ModelAttribute KycSubmissionRequest request) {
    return authService.verifyKyc(request);
  }
}
