package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.common.exception.ConflictException;
import com.example.the_guardian_v1.common.exception.UnauthorizedException;
import com.example.the_guardian_v1.common.exception.ValidationException;
import com.example.the_guardian_v1.domain.model.Parent;
import com.example.the_guardian_v1.dto.auth.*;
import com.example.the_guardian_v1.repository.ParentRepository;
import com.example.the_guardian_v1.security.JwtService;
import com.example.the_guardian_v1.service.IAuthService;
import com.example.the_guardian_v1.service.IEmailService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.Random;
import java.util.UUID;

@Service
@Slf4j
public class AuthServiceImpl implements IAuthService {

  private final ParentRepository parentRepository;
  private final PasswordEncoder passwordEncoder;
  private final JwtService jwtService;
  private final IEmailService emailService;

  public AuthServiceImpl(ParentRepository parentRepository, PasswordEncoder passwordEncoder,
      JwtService jwtService, IEmailService emailService) {
    this.parentRepository = parentRepository;
    this.passwordEncoder = passwordEncoder;
    this.jwtService = jwtService;
    this.emailService = emailService;
  }

  @Override
  public LoginResponse login(LoginRequest request) {
    log.info("Tentative de connexion pour l'email : {}", request.email);
    Parent p = parentRepository.findByEmail(request.email)
        .orElseThrow(() -> {
          log.warn("Tentative de connexion échouée : email non trouvé {}", request.email);
          return new UnauthorizedException("Invalid credentials");
        });

    if (!passwordEncoder.matches(request.password, p.getPasswordHash())) {
      log.warn("Tentative de connexion échouée : mot de passe incorrect pour {}", request.email);
      throw new UnauthorizedException("Invalid credentials");
    }

    // Auto-verify if not verified (OTP bypass)
    if (!p.getVerified()) {
      log.info("Activation automatique du compte non vérifié pendant le login pour {}", request.email);
      p.setVerified(true);
      p.setStatus("ACTIVE");
      parentRepository.save(p);
    }

    if (p.getStatus() != null && !"ACTIVE".equalsIgnoreCase(p.getStatus())) {
      log.warn("Tentative de connexion échouée : compte inactif {}", request.email);
      throw new UnauthorizedException("Account is not active");
    }

    String token = jwtService.generateAccessToken(p.getId(), Map.of("email", p.getEmail()));
    log.info("Connexion réussie pour {}", request.email);

    LoginResponse resp = new LoginResponse();
    resp.accessToken = token;
    resp.expiresInSeconds = jwtService.getTtlSeconds();
    LoginResponse.ParentSummary ps = new LoginResponse.ParentSummary();
    ps.parentId = p.getId();
    ps.name = p.getName();
    ps.email = p.getEmail();
    resp.parent = ps;
    return resp;
  }

  @Override
  public RegisterResponse register(RegisterRequest request) {
    log.info("Tentative d'inscription pour l'email (OTP désactivé) : {}", request.email);

    // Check if email already exists
    java.util.Optional<Parent> existingParent = parentRepository.findByEmail(request.email);
    if (existingParent.isPresent()) {
      Parent p = existingParent.get();
      log.info("L'email {} existe déjà. Mise à jour du compte (OTP BYPASSED).", request.email);

      p.setName(request.name);
      p.setPasswordHash(passwordEncoder.encode(request.password));
      p.setVerified(true);
      p.setStatus("ACTIVE");
      p.setOtpCode(null);
      p.setOtpExpiresAt(null);
      parentRepository.save(p);

      RegisterResponse response = new RegisterResponse();
      response.parentId = p.getId();
      response.email = p.getEmail();
      response.message = "Compte mis à jour (OTP désactivé).";
      return response;
    }

    // Create parent (Verified by default - OTP BYPASS)
    Parent parent = new Parent();
    parent.setId(UUID.randomUUID().toString());
    parent.setName(request.name);
    parent.setEmail(request.email);
    parent.setPasswordHash(passwordEncoder.encode(request.password));
    parent.setPhoneNumber(request.phoneNumber);
    parent.setVerified(true);
    parent.setStatus("ACTIVE");
    parent.setOtpCode(null);
    parent.setOtpExpiresAt(null);

    parentRepository.save(parent);
    log.info("Parent créé et ACTIVÉ directement (OTP BYPASS) pour {}", request.email);

    RegisterResponse response = new RegisterResponse();
    response.parentId = parent.getId();
    response.email = parent.getEmail();
    response.message = "Inscription réussie (OTP désactivé).";
    return response;
  }

  @Override
  public VerifyOtpResponse verifyOtp(VerifyOtpRequest request) {
    log.info("Tentative de vérification OTP pour l'email : {}", request.email);

    Parent parent = parentRepository.findByEmail(request.email)
        .orElseThrow(() -> new ValidationException("Invalid email or OTP code"));

    // Check if already verified
    if (parent.getVerified()) {
      throw new ValidationException("Account already verified");
    }

    // Check OTP code
    if (parent.getOtpCode() == null || !parent.getOtpCode().equals(request.otpCode)) {
      log.warn("OTP invalide pour l'email : {}", request.email);
      throw new ValidationException("Invalid email or OTP code");
    }

    // Check OTP expiration
    if (parent.getOtpExpiresAt() == null || LocalDateTime.now().isAfter(parent.getOtpExpiresAt())) {
      log.warn("OTP expiré pour l'email : {}", request.email);
      throw new ValidationException("OTP code has expired. Please request a new one.");
    }

    // Activate account
    parent.setVerified(true);
    parent.setStatus("ACTIVE");
    parent.setOtpCode(null);
    parent.setOtpExpiresAt(null);
    parentRepository.save(parent);
    log.info("Compte vérifié et activé avec succès pour {}", request.email);

    // Generate JWT token
    String token = jwtService.generateAccessToken(parent.getId(), Map.of("email", parent.getEmail()));

    VerifyOtpResponse response = new VerifyOtpResponse();
    response.success = true;
    response.message = "Account verified successfully";
    response.accessToken = token;
    response.expiresInSeconds = jwtService.getTtlSeconds();
    return response;
  }

  @Override
  public void verifyKyc(KycRequest request) {
    log.info("Vérification KYC pour l'email du parent connecté");
    // In a real scenario, we would get the parent from SecurityContext
    // For now, we assume search by name or other unique KYC field for demo,
    // but ideally, we need the authenticated parent's context.
    // Adding a generic mock logic for KYC verification.
    Parent p = parentRepository.findAll().stream()
        .filter(parent -> parent.getName().equalsIgnoreCase(request.getFullName()))
        .findFirst()
        .orElseThrow(() -> new ValidationException("Parent not found with name: " + request.getFullName()));

    p.setKycVerified(true);
    p.setKycDocumentType(request.getDocumentType());
    p.setKycDocumentNumber(request.getDocumentNumber());
    parentRepository.save(p);
    log.info("KYC vérifié avec succès pour {}", request.getFullName());
  }

  private String generateOtp() {
    Random random = new Random();
    int otp = 100000 + random.nextInt(900000);
    return String.valueOf(otp);
  }
}
