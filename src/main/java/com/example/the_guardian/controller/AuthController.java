package com.example.the_guardian.controller;

import com.example.the_guardian.dto.auth.AuthResponse;
import com.example.the_guardian.dto.auth.LoginRequest;
import com.example.the_guardian.dto.auth.RegisterRequest;
import com.example.the_guardian.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    /**
     * POST /api/auth/register
     * Inscription d'un nouveau parent
     */
    @PostMapping("/register")
    @Operation(summary = "Inscription utilisateur", description = "Permet à un nouvel utilisateur de créer un compte")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        AuthResponse response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * POST /api/auth/login
     * Connexion d'un parent
     */
    @PostMapping("/login")
    @Operation(summary = "Connexion utilisateur", description = "Permet à un utilisateur de se connecter avec email et mot de passe")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(response);
    }

    /**
     * POST /api/auth/verify
     * Vérification du compte
     */
    @PostMapping("/verify")
    @Operation(summary = "Vérification OTP", description = "Vérifie le code OTP envoyé par email")
    public ResponseEntity<Void> verifyAccount(
            @Valid @RequestBody com.example.the_guardian.dto.auth.VerifyAccountRequest request) {
        authService.verifyAccount(request);
        return ResponseEntity.ok().build();
    }

    /**
     * GET /api/auth/health
     * Healthcheck
     */
    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("Auth service is running");
    }
}