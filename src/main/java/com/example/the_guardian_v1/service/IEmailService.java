package com.example.the_guardian_v1.service;

public interface IEmailService {
    void sendOtpEmail(String toEmail, String otpCode);
}
