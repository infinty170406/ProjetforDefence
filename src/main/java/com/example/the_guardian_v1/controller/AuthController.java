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
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
@Tag(name = "Authentication", description = "Endpoints pour l'authentification des parents")
public class AuthController {
  private final IAuthService authService;

  public AuthController(IAuthService authService) {
    this.authService = authService;
  }

  @PostMapping("/login")
  @Operation(summary = "Connexion d'un parent", description = "Authentifie un parent avec son email et mot de passe. Le compte doit être vérifié.")
  @ApiResponses(value = {
      @ApiResponse(responseCode = "200", description = "Connexion réussie", content = @Content(schema = @Schema(implementation = LoginResponse.class))),
      @ApiResponse(responseCode = "401", description = "Identifiants invalides ou compte non vérifié")
  })
  public LoginResponse login(@Valid @RequestBody LoginRequest request) {
    return authService.login(request);
  }

  @PostMapping("/register")
  @Operation(summary = "Inscription d'un nouveau parent", description = "Crée un nouveau compte parent et envoie un code OTP par email pour vérification")
  @ApiResponses(value = {
      @ApiResponse(responseCode = "200", description = "Inscription réussie, OTP envoyé par email", content = @Content(schema = @Schema(implementation = RegisterResponse.class))),
      @ApiResponse(responseCode = "409", description = "Email déjà utilisé")
  })
  public RegisterResponse register(@Valid @RequestBody RegisterRequest request) {
    return authService.register(request);
  }

  @PostMapping("/verify-otp")
  @Operation(summary = "Vérification du code OTP", description = "Vérifie le code OTP reçu par email et active le compte. Retourne un token JWT.")
  @ApiResponses(value = {
      @ApiResponse(responseCode = "200", description = "Vérification réussie, compte activé", content = @Content(schema = @Schema(implementation = VerifyOtpResponse.class))),
      @ApiResponse(responseCode = "400", description = "Code OTP invalide ou expiré")
  })
  public VerifyOtpResponse verifyOtp(@Valid @RequestBody VerifyOtpRequest request) {
    return authService.verifyOtp(request);
  }
}
