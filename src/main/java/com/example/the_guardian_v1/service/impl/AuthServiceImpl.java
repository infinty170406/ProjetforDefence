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
    if (parentRepository.findByEmail(request.email).isPresent()) {
      throw new ConflictException("L'email est déjà utilisé.");
    }

    // Create parent object (but don't save to DB yet)
    Parent parent = new Parent();
    parent.setId(UUID.randomUUID().toString());
    parent.setName(request.name);
    parent.setEmail(request.email);
    parent.setPasswordHash(passwordEncoder.encode(request.password));
    parent.setPhoneNumber(request.phoneNumber);
    parent.setVerified(false);
    parent.setKycVerified(false);
    parent.setStatus("PENDING_KYC");

    // Store in Redis instead of DB
    // Use Name as key for KYC matching as requested (Risk of collision noted in
    // plan)
    String redisKey = PENDING_PARENT_KEY_PREFIX + request.name;
    redisTemplate.opsForValue().set(redisKey, parent, 30, java.util.concurrent.TimeUnit.MINUTES);
    log.info("Parent stocké temporairement en Redis (clé: {}) pour {}", redisKey, request.email);

    RegisterResponse response = new RegisterResponse();
    response.parentId = parent.getId();
    response.email = parent.getEmail();
    response.message = "Inscription reçue. Veuillez maintenant procéder à la vérification KYC pour activer votre compte.";
    return response;
  }

  @Override
  public VerifyOtpResponse verifyOtp(VerifyOtpRequest request) {
    // This method is now deactivated as per user request
    log.warn("Tentative d'appel à verifyOtp (service désactivé)");
    throw new ValidationException("Le service OTP est désactivé. Veuillez utiliser le KYC pour valider votre compte.");
  }

  @Override
  public KycResponse verifyKyc(KycSubmissionRequest request) {
    log.info("Traitement de la soumission KYC pour : {}", request.getFullName());

    // 1. Basic Security Validations (File types)
    validateImageFile(request.getDocumentImage());
    validateImageFile(request.getSelfieImage());

    // 2. Identify the parent (Check Redis first, then fallback to DB)
    String redisKey = PENDING_PARENT_KEY_PREFIX + request.getFullName();
    Object pendingObj = redisTemplate.opsForValue().get(redisKey);
    Parent p;

    if (pendingObj instanceof Parent) {
      p = (Parent) pendingObj;
      log.info("Parent en attente trouvé en Redis pour {}", request.getFullName());
    } else {
      p = parentRepository.findByNameIgnoreCase(request.getFullName())
          .orElseThrow(() -> new ValidationException("Utilisateur non trouvé : " + request.getFullName()));
      log.info("Parent trouvé en DB pour KYC (cas existant) pour {}", request.getFullName());
    }

    // 3. Call the external KYC service
    KycResponse kycResponse = kycService.verifyKyc(request);

    // 4. Update Parent entity based on result
    if (kycResponse.getStatus() == KycResponse.Status.APPROVED) {
      p.setKycVerified(true);
      p.setVerified(true); // Account is verified only after KYC approval
      p.setKycDocumentType(request.getDocumentType());
      p.setKycDocumentNumber(request.getDocumentNumber());
      p.setStatus("ACTIVE");

      parentRepository.save(p);
      if (pendingObj != null) {
        redisTemplate.delete(redisKey);
      }
      log.info("KYC APPROUVÉ et parent enregistré en DB pour {}", request.getFullName());
    } else {
      p.setKycVerified(false);
      // If it was already in DB, update status
      if (p.getId() != null && parentRepository.existsById(p.getId())) {
        parentRepository.save(p);
      }
      log.warn("KYC REJETÉ pour {} : {}", request.getFullName(), kycResponse.getReason());
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
