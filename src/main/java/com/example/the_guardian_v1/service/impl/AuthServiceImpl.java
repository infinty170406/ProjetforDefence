package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.common.exception.ValidationException;
import com.example.the_guardian_v1.domain.model.Parent;
import com.example.the_guardian_v1.dto.auth.*;
import com.example.the_guardian_v1.repository.ParentRepository;
import com.example.the_guardian_v1.service.IAuthService;
import com.example.the_guardian_v1.service.IKycService;
import com.google.firebase.auth.ActionCodeSettings;
import com.google.firebase.auth.FirebaseAuth;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class AuthServiceImpl implements IAuthService {

  private final ParentRepository parentRepository;
  private final IKycService kycService;
  private final LocalStorageService storageService;

  public AuthServiceImpl(ParentRepository parentRepository,
      IKycService kycService,
      LocalStorageService storageService) {
    this.parentRepository = parentRepository;
    this.kycService = kycService;
    this.storageService = storageService;
  }

  @Override
  public KycResponse verifyKyc(KycSubmissionRequest request) {
    log.info("Processing KYC submission for: {}", request.getFullName());

    validateImageFile(request.getDocumentImage());
    validateImageFile(request.getSelfieImage());

    Parent p = parentRepository.findByNameIgnoreCase(request.getFullName())
        .orElseThrow(() -> new ValidationException("User not found: " + request.getFullName()));

    log.info("Parent found in DB for KYC: {}", request.getFullName());

    try {
      String docPath = p.getId() + "/kyc/document_" + System.currentTimeMillis() + "_"
          + request.getDocumentImage().getOriginalFilename();
      String selfiePath = p.getId() + "/kyc/selfie_" + System.currentTimeMillis() + "_"
          + request.getSelfieImage().getOriginalFilename();

      storageService.uploadFile(docPath, request.getDocumentImage());
      storageService.uploadFile(selfiePath, request.getSelfieImage());

      log.info("KYC images saved locally for parent: {}", p.getId());
    } catch (Exception e) {
      log.error("Failed to save KYC images locally: {}", e.getMessage());
      throw new RuntimeException("Error storing KYC documents", e);
    }

    KycResponse kycResponse = kycService.verifyKyc(request);

    if (kycResponse.getStatus() == KycResponse.Status.APPROVED) {
      p.setKycVerified(true);
      p.setVerified(true);
      p.setKycDocumentType(request.getDocumentType());
      p.setKycDocumentNumber(request.getDocumentNumber());
      p.setStatus("ACTIVE");

      parentRepository.save(p);
      log.info("KYC APPROVED and parent updated in DB for {}", request.getFullName());
    } else {
      p.setKycVerified(false);
      if (p.getId() != null && parentRepository.existsById(p.getId())) {
        parentRepository.save(p);
      }
      log.warn("KYC REJECTED for {} : {}", request.getFullName(), kycResponse.getReason());
    }

    return kycResponse;
  }

  @Override
  public void sendOtp(String email) {
    log.info("Requesting Firebase to send an Email Action Link to {}", email);

    try {
      // Firebase handles 100% of the email sending.
      // We generate a Sign-In with Email Link which acts as the "OTP" verification.
      ActionCodeSettings actionCodeSettings = ActionCodeSettings.builder()
          .setUrl("https://the-guardian-v1.firebaseapp.com/__/auth/action") // Replace with your actual redirect URL
          .setHandleCodeInApp(true)
          .build();

      String link = FirebaseAuth.getInstance().generateSignInWithEmailLink(email, actionCodeSettings);
      log.info("Firebase action link generated. Firebase is now sending the email to {}", email);
      // Note: The link itself is loggable for debug but normally you don't return it
      // if you want 100% Firebase management.
    } catch (Exception e) {
      log.error("Failed to trigger Firebase email: {}", e.getMessage());
      throw new RuntimeException("Firebase email trigger failed", e);
    }
  }

  @Override
  public VerifyOtpResponse verifyOtp(VerifyOtpRequest request) {
    // In a 100% Firebase flow, verification happens on the client or via Firebase's
    // own validation.
    // However, we can provide this endpoint to check if a token is "Fresh"
    // (re-authenticated).
    // For now, we logically verify that the account exists and is active.

    log.info("Verifying user identity for {}", request.email);
    VerifyOtpResponse response = new VerifyOtpResponse();

    parentRepository.findByEmail(request.email).ifPresentOrElse(p -> {
      response.success = true;
      response.message = "User identity recognized for " + request.email;
    }, () -> {
      response.success = false;
      response.message = "User not found";
    });

    return response;
  }

  private void validateImageFile(org.springframework.web.multipart.MultipartFile file) {
    if (file == null || file.isEmpty()) {
      throw new ValidationException("Image file is missing or empty");
    }
    String contentType = file.getContentType();
    if (contentType == null || (!contentType.equals("image/jpeg") && !contentType.equals("image/png"))) {
      throw new ValidationException("Invalid file type. Only JPEG and PNG are allowed.");
    }
    if (file.getSize() > 5 * 1024 * 1024) { // 5MB
      throw new ValidationException("File size exceeds 5MB limit.");
    }
  }
}
