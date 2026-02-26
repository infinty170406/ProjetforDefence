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
import com.example.the_guardian_v1.service.IKycService;
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
  private final IKycService kycService;
  private final org.springframework.data.redis.core.RedisTemplate<String, Object> redisTemplate;
  private static final String PENDING_PARENT_KEY_PREFIX = "pending_parent:";

  public AuthServiceImpl(ParentRepository parentRepository, PasswordEncoder passwordEncoder,
      JwtService jwtService, IEmailService emailService, IKycService kycService,
      org.springframework.data.redis.core.RedisTemplate<String, Object> redisTemplate) {
    this.parentRepository = parentRepository;
    this.passwordEncoder = passwordEncoder;
    this.jwtService = jwtService;
    this.emailService = emailService;
    this.kycService = kycService;
    this.redisTemplate = redisTemplate;
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

    // Check if verified
    if (!p.getVerified()) {
      log.warn("Tentative de connexion échouée : compte non vérifié {}", request.email);
      throw new UnauthorizedException("Account is not verified. Please verify your OTP.");
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
    log.info("Tentative d'inscription pour l'email : {}", request.email);

    // Check if email already exists in DB
    java.util.Optional<Parent> existingParent = parentRepository.findByEmail(request.email);
    if (existingParent.isPresent()) {
      Parent p = existingParent.get();
      if (p.getVerified()) {
        log.info("L'email {} est déjà inscrit et vérifié.", request.email);
        throw new ConflictException("L'email est déjà utilisé et vérifié.");
      }
      log.info("L'email {} existe déjà en DB mais n'est pas vérifié. Nous allons écraser la demande en Redis.",
          request.email);
    }

    // Create parent object (but don't save to DB yet)
    Parent parent = new Parent();
    parent.setId(UUID.randomUUID().toString());
    parent.setName(request.name);
    parent.setEmail(request.email);
    parent.setPasswordHash(passwordEncoder.encode(request.password));
    parent.setPhoneNumber(request.phoneNumber);
    parent.setVerified(false);
    parent.setStatus("PENDING");

    String otp = generateOtp();
    parent.setOtpCode(otp);
    parent.setOtpExpiresAt(LocalDateTime.now().plusMinutes(10));

    // Store in Redis instead of DB
    String redisKey = PENDING_PARENT_KEY_PREFIX + request.email;
    redisTemplate.opsForValue().set(redisKey, parent, 10, java.util.concurrent.TimeUnit.MINUTES);
    log.info("Parent stocké temporairement en Redis pour {}", request.email);

    try {
      emailService.sendOtpEmail(parent.getEmail(), otp);
      log.info("OTP envoyé par email à {}", request.email);
    } catch (Exception e) {
      log.error("Erreur lors de l'envoi de l'OTP par email", e);
    }

    RegisterResponse response = new RegisterResponse();
    response.parentId = parent.getId();
    response.email = parent.getEmail();
    response.message = "Inscription initiée. Veuillez vérifier votre email pour le code OTP.";
    return response;
  }

  @Override
  public VerifyOtpResponse verifyOtp(VerifyOtpRequest request) {
    log.info("Tentative de vérification OTP pour l'email : {}", request.email);

    String redisKey = PENDING_PARENT_KEY_PREFIX + request.email;
    Object pendingObj = redisTemplate.opsForValue().get(redisKey);
    Parent parent;

    if (pendingObj instanceof Parent) {
      parent = (Parent) pendingObj;
      log.info("Parent trouvé en Redis pour {}", request.email);
    } else {
      // Fallback to DB for already registered but unverified users (legacy)
      parent = parentRepository.findByEmail(request.email)
          .orElseThrow(() -> new ValidationException("Demande d'inscription non trouvée ou expirée."));
      log.info("Parent trouvé en DB pour conversion (fallback) pour {}", request.email);
    }

    // Check if already verified (only if found in DB)
    if (Boolean.TRUE.equals(parent.getVerified()) && parent.getId() != null) {
      // Check if it's already in DB by ID
      if (parentRepository.existsById(parent.getId())) {
        throw new ValidationException("Account already verified");
      }
    }

    // Check OTP code
    if (parent.getOtpCode() == null || !parent.getOtpCode().equals(request.otpCode)) {
      log.warn("OTP invalide pour l'email : {}", request.email);
      throw new ValidationException("Code OTP invalide.");
    }

    // Check OTP expiration
    if (parent.getOtpExpiresAt() == null || LocalDateTime.now().isAfter(parent.getOtpExpiresAt())) {
      log.warn("OTP expiré pour l'email : {}", request.email);
      throw new ValidationException("Le code OTP a expiré.");
    }

    // Activate and SAVE to DB
    parent.setVerified(true);
    parent.setStatus("ACTIVE");
    parent.setOtpCode(null);
    parent.setOtpExpiresAt(null);

    parentRepository.save(parent);
    redisTemplate.delete(redisKey); // Clean up Redis
    log.info("Compte vérifié, enregistré en DB et activé pour {}", request.email);

    // Generate JWT token
    String token = jwtService.generateAccessToken(parent.getId(), Map.of("email", parent.getEmail()));

    VerifyOtpResponse response = new VerifyOtpResponse();
    response.success = true;
    response.message = "Compte vérifié avec succès";
    response.accessToken = token;
    response.expiresInSeconds = jwtService.getTtlSeconds();
    return response;
  }

  @Override
  public KycResponse verifyKyc(KycSubmissionRequest request) {
    log.info("Processing KYC submission for: {}", request.getFullName());

    // 1. Basic Security Validations (File types)
    validateImageFile(request.getDocumentImage());
    validateImageFile(request.getSelfieImage());

    // 2. Identify the parent
    // In production, this would use the authenticated user (SecurityContextHolder)
    Parent p = parentRepository.findByNameIgnoreCase(request.getFullName())
        .orElseThrow(() -> new ValidationException("User not found: " + request.getFullName()));

    // 3. Call the external KYC service
    KycResponse kycResponse = kycService.verifyKyc(request);

    // 4. Update Parent entity based on result (including Age check requirement)
    if (kycResponse.getStatus() == KycResponse.Status.APPROVED) {
      // Business Rule: Age >= 18 is assumed to be verified by the OCR microservice
      // if it returns APPROVED. If confidence is high, we proceed.
      p.setKycVerified(true);
      p.setKycDocumentType(request.getDocumentType());
      p.setKycDocumentNumber(request.getDocumentNumber());
      parentRepository.save(p);
      log.info("KYC APPROVED and saved for {}", request.getFullName());
    } else {
      p.setKycVerified(false);
      parentRepository.save(p);
      log.warn("KYC REJECTED for {}: {}", request.getFullName(), kycResponse.getReason());
    }

    return kycResponse;
  }

  private void validateImageFile(org.springframework.web.multipart.MultipartFile file) {
    if (file == null || file.isEmpty()) {
      throw new ValidationException("Image file is missing or empty");
    }
    String contentType = file.getContentType();
    if (contentType == null || (!contentType.equals("image/jpeg") && !contentType.equals("image/png"))) {
      throw new ValidationException("Invalid file type. Only JPEG and PNG are allowed.");
    }
    // Size limit check (also enforced by Spring Config)
    if (file.getSize() > 5 * 1024 * 1024) { // 5MB
      throw new ValidationException("File size exceeds 5MB limit.");
    }
  }

  private String generateOtp() {
    Random random = new Random();
    int otp = 100000 + random.nextInt(900000);
    return String.valueOf(otp);
  }
}
