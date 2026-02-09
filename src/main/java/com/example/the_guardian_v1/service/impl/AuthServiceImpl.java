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
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.Random;
import java.util.UUID;

@Service
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
    Parent p = parentRepository.findByEmail(request.email)
        .orElseThrow(() -> new UnauthorizedException("Invalid credentials"));

    if (!passwordEncoder.matches(request.password, p.getPasswordHash())) {
      throw new UnauthorizedException("Invalid credentials");
    }

    if (!p.getVerified()) {
      throw new UnauthorizedException("Account not verified. Please verify your email first.");
    }

    if (p.getStatus() != null && !"ACTIVE".equalsIgnoreCase(p.getStatus())) {
      throw new UnauthorizedException("Account is not active");
    }

    String token = jwtService.generateAccessToken(p.getId(), Map.of("email", p.getEmail()));
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
    // Check if email already exists
    if (parentRepository.findByEmail(request.email).isPresent()) {
      throw new ConflictException("Email already registered");
    }

    // Generate OTP
    String otpCode = generateOtp();
    LocalDateTime otpExpiresAt = LocalDateTime.now().plusMinutes(10);

    // Create parent
    Parent parent = new Parent();
    parent.setId(UUID.randomUUID().toString());
    parent.setName(request.name);
    parent.setEmail(request.email);
    parent.setPasswordHash(passwordEncoder.encode(request.password));
    parent.setPhoneNumber(request.phoneNumber);
    parent.setStatus("PENDING");
    parent.setVerified(false);
    parent.setOtpCode(otpCode);
    parent.setOtpExpiresAt(otpExpiresAt);

    parentRepository.save(parent);

    // Send OTP email
    try {
      emailService.sendOtpEmail(parent.getEmail(), otpCode);
    } catch (Exception e) {
      // Log error but don't fail registration
      System.err.println("Failed to send OTP email: " + e.getMessage());
    }

    RegisterResponse response = new RegisterResponse();
    response.parentId = parent.getId();
    response.email = parent.getEmail();
    response.message = "Registration successful. Please check your email for the verification code.";
    return response;
  }

  @Override
  public VerifyOtpResponse verifyOtp(VerifyOtpRequest request) {
    Parent parent = parentRepository.findByEmail(request.email)
        .orElseThrow(() -> new ValidationException("Invalid email or OTP code"));

    // Check if already verified
    if (parent.getVerified()) {
      throw new ValidationException("Account already verified");
    }

    // Check OTP code
    if (parent.getOtpCode() == null || !parent.getOtpCode().equals(request.otpCode)) {
      throw new ValidationException("Invalid email or OTP code");
    }

    // Check OTP expiration
    if (parent.getOtpExpiresAt() == null || LocalDateTime.now().isAfter(parent.getOtpExpiresAt())) {
      throw new ValidationException("OTP code has expired. Please request a new one.");
    }

    // Activate account
    parent.setVerified(true);
    parent.setStatus("ACTIVE");
    parent.setOtpCode(null);
    parent.setOtpExpiresAt(null);
    parentRepository.save(parent);

    // Generate JWT token
    String token = jwtService.generateAccessToken(parent.getId(), Map.of("email", parent.getEmail()));

    VerifyOtpResponse response = new VerifyOtpResponse();
    response.success = true;
    response.message = "Account verified successfully";
    response.accessToken = token;
    response.expiresInSeconds = jwtService.getTtlSeconds();
    return response;
  }

  private String generateOtp() {
    Random random = new Random();
    int otp = 100000 + random.nextInt(900000);
    return String.valueOf(otp);
  }
}
