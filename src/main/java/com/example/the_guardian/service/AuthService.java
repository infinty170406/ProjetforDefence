package com.example.the_guardian.service;

import com.example.the_guardian.dto.auth.AuthResponse;
import com.example.the_guardian.dto.auth.LoginRequest;
import com.example.the_guardian.dto.auth.RegisterRequest;
import com.example.the_guardian.entity.Parent;
import com.example.the_guardian.repository.ParentRepository;
import com.example.the_guardian.security.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final ParentRepository parentRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    /**
     * Inscription d'un nouveau parent
     */
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        // Vérifier si l'email existe déjà
        if (parentRepository.existsByEmail(request.getEmail())) {
            throw new IllegalArgumentException("Un compte existe déjà avec cet email");
        }

        // Créer le parent
        Parent parent = Parent.builder()
                .email(request.getEmail())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .firstName(request.getFirstName())
                .lastName(request.getLastName())
                .phone(request.getPhone())
                .isActive(true)
                .build();

        parent = parentRepository.save(parent);

        log.info("New parent registered: {}", parent.getEmail());

        // Générer le token JWT
        String token = jwtUtil.generateParentToken(parent.getId(), parent.getEmail());

        return new AuthResponse(
                token,
                parent.getId(),
                parent.getEmail(),
                parent.getFirstName(),
                parent.getLastName()
        );
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
        log.info("Hash en base : {}", parent.getPasswordHash());
        log.info("Password envoyé : {}", request.getPassword());

        // Vérifier le mot de passe
        boolean matches = passwordEncoder.matches(request.getPassword(), parent.getPasswordHash());
        log.info("Password match : {}", matches);

        if (!matches) {
            log.error("Mot de passe incorrect pour : {}", request.getEmail());
            throw new IllegalArgumentException("Email ou mot de passe incorrect");
        }

        // Vérifier si le compte est actif
        if (!parent.getIsActive()) {
            throw new IllegalStateException("Ce compte est désactivé");
        }

        log.info("Parent logged in: {}", parent.getEmail());

        // Générer le token JWT
        String token = jwtUtil.generateParentToken(parent.getId(), parent.getEmail());

        return new AuthResponse(
                token,
                parent.getId(),
                parent.getEmail(),
                parent.getFirstName(),
                parent.getLastName()
        );
    }
}