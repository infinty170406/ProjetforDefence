package com.example.the_guardian.service;

import com.example.the_guardian.dto.auth.AuthResponse;
import com.example.the_guardian.dto.auth.LoginRequest;
import com.example.the_guardian.dto.auth.RegisterRequest;
import com.example.the_guardian.dto.auth.VerifyAccountRequest;
import com.example.the_guardian.entity.Parent;
import com.example.the_guardian.repository.ParentRepository;
import com.example.the_guardian.security.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Random;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final ParentRepository parentRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final EmailService emailService;

    /**
     * Inscription d'un nouveau parent
     */
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        // Vérifier si l'email existe déjà
        if (parentRepository.existsByEmail(request.getEmail())) {
            throw new IllegalArgumentException("Un compte existe déjà avec cet email");
        }

        // Générer OTP (6 chiffres)
        String otp = String.format("%06d", new Random().nextInt(999999));

        // Créer le parent
        Parent parent = Parent.builder()
                .email(request.getEmail())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .firstName(request.getFirstName())
                .lastName(request.getLastName())
                .phone(request.getPhone())
                .isActive(true)
                .emailVerified(false)
                .otpCode(otp)
                .otpExpiration(LocalDateTime.now().plusMinutes(15))
                .build();

        parent = parentRepository.save(parent);

        // Envoyer l'email de manière asynchrone
        emailService.sendVerificationEmail(parent.getEmail(), otp);

        log.info("New parent registered: {}", parent.getEmail());

        // Générer le token JWT
        String token = jwtUtil.generateParentToken(parent.getId(), parent.getEmail());

        return new AuthResponse(
                token,
                parent.getId(),
                parent.getEmail(),
                parent.getFirstName(),
                parent.getLastName());
    }

    /**
     * Verifier le compte avec l'OTP
     */
    @Transactional
    public void verifyAccount(VerifyAccountRequest request) {
        Parent parent = parentRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new IllegalArgumentException("Email introuvable"));

        if (parent.isEmailVerified()) {
            return; // Déjà vérifié, on renvoie 200 OK
        }

        if (parent.getOtpCode() == null || parent.getOtpExpiration().isBefore(LocalDateTime.now())) {
            throw new IllegalArgumentException("Code expiré ou invalide. Veuillez demander un nouveau code.");
        }

        if (!parent.getOtpCode().equals(request.getOtp())) {
            throw new IllegalArgumentException("Code incorrect");
        }

        // Valider le compte
        parent.setEmailVerified(true);
        parent.setOtpCode(null);
        parent.setOtpExpiration(null);

        parentRepository.save(parent);
        log.info("Compte vérifié pour : {}", parent.getEmail());
    }

    /**
     * Connexion d'un parent
     */
    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        log.info(" Tentative de login pour : {}", request.getEmail());

        // Trouver le parent
        Parent parent = parentRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> {
                    log.error("Email introuvable : {}", request.getEmail());
                    return new IllegalArgumentException("Email ou mot de passe incorrect");
                });

        log.info("Parent trouvé : {}", parent.getEmail());

        // Vérifier le mot de passe
        boolean matches = passwordEncoder.matches(request.getPassword(), parent.getPasswordHash());

        if (!matches) {
            log.error("Mot de passe incorrect pour : {}", request.getEmail());
            throw new IllegalArgumentException("Email ou mot de passe incorrect");
        }

        // Vérifier si le compte est actif
        if (!parent.getIsActive()) {
            throw new IllegalStateException("Ce compte est désactivé");
        }

        log.info(" Parent logged in: {}", parent.getEmail());

        // Générer le token JWT
        String token = jwtUtil.generateParentToken(parent.getId(), parent.getEmail());

        return new AuthResponse(
                token,
                parent.getId(),
                parent.getEmail(),
                parent.getFirstName(),
                parent.getLastName());
    }
}