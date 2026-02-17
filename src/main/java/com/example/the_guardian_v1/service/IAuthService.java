package com.example.the_guardian_v1.service;

import com.example.the_guardian_v1.dto.auth.*;

public interface IAuthService {
    LoginResponse login(LoginRequest request);

    RegisterResponse register(RegisterRequest request);

    VerifyOtpResponse verifyOtp(VerifyOtpRequest request);
}
