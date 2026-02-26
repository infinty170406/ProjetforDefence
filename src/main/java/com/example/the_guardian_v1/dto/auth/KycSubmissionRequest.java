package com.example.the_guardian_v1.dto.auth;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.web.multipart.MultipartFile;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class KycSubmissionRequest {
    @NotBlank(message = "Document type is required")
    private String documentType;

    @NotBlank(message = "Document number is required")
    private String documentNumber;

    @NotBlank(message = "Full name as on document is required")
    private String fullName;

    @NotNull(message = "Document image is required")
    private MultipartFile documentImage;

    @NotNull(message = "Selfie image is required")
    private MultipartFile selfieImage;
}
