package com.example.the_guardian_v1.service;

import com.example.the_guardian_v1.dto.auth.KycResponse;
import com.example.the_guardian_v1.dto.auth.KycSubmissionRequest;
import com.example.the_guardian_v1.dto.auth.VerifyOtpRequest;
import com.example.the_guardian_v1.dto.auth.VerifyOtpResponse;

public interface IAuthService {

    KycResponse verifyKyc(KycSubmissionRequest request);

    /**
     * Generates a 6-digit OTP, stores it in Redis for 10 minutes,
     * and sends it to the given email via SMTP.
     */
    void sendOtp(String email);

    /**
     * Verifies the OTP submitted by the user.
     * Deletes the OTP from Redis on success.
     */
    VerifyOtpResponse verifyOtp(VerifyOtpRequest request);
}
