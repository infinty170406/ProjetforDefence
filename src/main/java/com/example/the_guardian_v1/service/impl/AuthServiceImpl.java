package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.common.exception.ValidationException;
import com.example.the_guardian_v1.domain.model.Parent;
import com.example.the_guardian_v1.dto.auth.*;
import com.example.the_guardian_v1.repository.ParentRepository;
import com.example.the_guardian_v1.service.IKycService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class AuthServiceImpl implements IAuthService {

  private final ParentRepository parentRepository;
  private final IKycService kycService;
  private final SupabaseStorageService storageService;

  public AuthServiceImpl(ParentRepository parentRepository, IKycService kycService,
      SupabaseStorageService storageService) {
    this.parentRepository = parentRepository;
    this.kycService = kycService;
    this.storageService = storageService;
  }

  @Override
  public KycResponse verifyKyc(KycSubmissionRequest request) {
    log.info("Traitement de la soumission KYC pour : {}", request.getFullName());

    // 1. Basic Security Validations (File types)
    validateImageFile(request.getDocumentImage());
    validateImageFile(request.getSelfieImage());

    // 2. Identify the parent from DB (should be created by SyncFilter if new)
    Parent p = parentRepository.findByNameIgnoreCase(request.getFullName())
        .orElseThrow(() -> new ValidationException("Utilisateur non trouvé : " + request.getFullName()));
    log.info("Parent trouvé en DB pour KYC pour {}", request.getFullName());

    // 2.5 Upload images to Supabase Storage
    try {
      String docPath = p.getId() + "/kyc/document_" + System.currentTimeMillis() + "_"
          + request.getDocumentImage().getOriginalFilename();
      String selfiePath = p.getId() + "/kyc/selfie_" + System.currentTimeMillis() + "_"
          + request.getSelfieImage().getOriginalFilename();

      storageService.uploadFile(docPath, request.getDocumentImage());
      storageService.uploadFile(selfiePath, request.getSelfieImage());

      log.info("KYC images uploaded to Supabase for parent: {}", p.getId());
    } catch (Exception e) {
      log.error("Failed to upload KYC images to Supabase: {}", e.getMessage());
      // Continue with verification anyway? Or fail? User said "Manage 100% of
      // storage".
      // Let's fail if storage fails to be strict.
      throw new RuntimeException("Erreur lors du stockage des documents KYC", e);
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
      log.info("KYC APPROUVÉ et parent mis à jour en DB pour {}", request.getFullName());
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

}
