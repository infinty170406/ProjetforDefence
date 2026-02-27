package com.example.the_guardian_v1.service;

import com.example.the_guardian_v1.dto.auth.*;

public interface IAuthService {
    KycResponse verifyKyc(KycSubmissionRequest request);
}
