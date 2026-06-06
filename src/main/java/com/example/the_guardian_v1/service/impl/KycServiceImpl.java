package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.common.exception.ValidationException;
import com.example.the_guardian_v1.dto.auth.KycResponse;
import com.example.the_guardian_v1.dto.auth.KycSubmissionRequest;
import com.example.the_guardian_v1.service.IKycService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

@Service
@Slf4j
public class KycServiceImpl implements IKycService {

    private final RestTemplate restTemplate;

    @Value("${kyc.service.url:http://localhost:5000/verify}")
    private String kycServiceUrl;

    public KycServiceImpl(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    @Override
    public KycResponse verifyKyc(KycSubmissionRequest request) {
        log.info("Starting KYC verification for: {}", request.getFullName());

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.MULTIPART_FORM_DATA);

            MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
            body.add("documentType", request.getDocumentType());
            body.add("documentNumber", request.getDocumentNumber());
            body.add("fullName", request.getFullName());
            body.add("documentImage", request.getDocumentImage().getResource());
            body.add("selfieImage", request.getSelfieImage().getResource());

            HttpEntity<MultiValueMap<String, Object>> entity = new HttpEntity<>(body, headers);

            ResponseEntity<KycResponse> response = restTemplate.postForEntity(kycServiceUrl, entity, KycResponse.class);

            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                KycResponse kycResult = response.getBody();
                log.info("KYC result for {}: status={}, confidence={}",
                        request.getFullName(), kycResult.getStatus(), kycResult.getConfidence());

                // Add business logic validation (e.g., minimum confidence)
                if (kycResult.getStatus() == KycResponse.Status.APPROVED && kycResult.getConfidence() < 0.7) {
                    log.warn("KYC marked as approved but confidence is low: {}", kycResult.getConfidence());
                    kycResult.setStatus(KycResponse.Status.REJECTED);
                    kycResult.setReason("Face match confidence too low");
                }

                return kycResult;
            } else {
                log.error("External KYC service returned error: {}", response.getStatusCode());
                throw new RuntimeException("External KYC service unavailable");
            }
        } catch (Exception e) {
            log.error("Error calling KYC service: {}", e.getMessage(), e);
            // Fallback strategy: return a rejection or rethrow
            throw new RuntimeException("KYC verification failed due to internal error: " + e.getMessage());
        }
    }
}
