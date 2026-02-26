package com.example.the_guardian_v1.service;

import com.example.the_guardian_v1.dto.auth.KycResponse;
import com.example.the_guardian_v1.dto.auth.KycSubmissionRequest;

public interface IKycService {
    KycResponse verifyKyc(KycSubmissionRequest request);
}
