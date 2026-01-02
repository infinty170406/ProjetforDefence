package com.example.the_guardian.auth.controller;

import com.example.the_guardian.auth.dto.request.*;
import com.example.the_guardian.auth.dto.response.AuthResponse;
import com.example.the_guardian.auth.dto.response.ChildDto;
import com.example.the_guardian.auth.dto.response.ApiResponse;
import com.example.the_guardian.auth.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Slf4j
public class AuthController {

    private final AuthService authService;

    // PARENT AUTHENTICATION ENDPOINTS

    @PostMapping("/parent/register")
    public ResponseEntity<ApiResponse<AuthResponse>> registerParent(
            @Valid @RequestBody ParentRegisterRequest request
    ) {
        log.info("POST /api/auth/parent/register - Email: {}", request.getEmail());
        AuthResponse response = authService.registerParent(request);
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ApiResponse.success(response, "Parent registered successfully"));
    }

    @PostMapping("/parent/login")
    public ResponseEntity<ApiResponse<AuthResponse>> loginParent(
            @Valid @RequestBody LoginRequest request
    ) {
        log.info("POST /api/auth/parent/login - Email: {}", request.getEmail());
        AuthResponse response = authService.loginParent(request);
        return ResponseEntity.ok(ApiResponse.success(response, "Login successful"));
    }

    // CHILD AUTHENTICATION ENDPOINTS

    @PostMapping("/child/login")
    public ResponseEntity<ApiResponse<AuthResponse>> loginChild(
            @Valid @RequestBody ChildLoginRequest request
    ) {
        log.info("POST /api/auth/child/login - ChildId: {}", request.getChildId());
        AuthResponse response = authService.loginChild(request);
        return ResponseEntity.ok(ApiResponse.success(response, "Child login successful"));
    }

    // CHILD MANAGEMENT ENDPOINTS (Parent Only)

    @PostMapping("/parent/children")
    @PreAuthorize("hasRole('PARENT')")
    public ResponseEntity<ApiResponse<ChildDto>> addChild(
            @AuthenticationPrincipal String parentId,
            @Valid @RequestBody AddChildRequest request
    ) {
        log.info("POST /api/auth/parent/children - ParentId: {}", parentId);
        ChildDto child = authService.addChild(parentId, request);
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ApiResponse.success(child, "Child added successfully"));
    }

    @GetMapping("/parent/children")
    @PreAuthorize("hasRole('PARENT')")
    public ResponseEntity<ApiResponse<List<ChildDto>>> getChildren(
            @AuthenticationPrincipal String parentId
    ) {
        log.info("GET /api/auth/parent/children - ParentId: {}", parentId);
        List<ChildDto> children = authService.getChildren(parentId);
        return ResponseEntity.ok(ApiResponse.success(children, "Children retrieved successfully"));
    }

    // TOKEN MANAGEMENT ENDPOINTS

    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<AuthResponse>> refreshToken(
            @Valid @RequestBody RefreshTokenRequest request
    ) {
        log.info("POST /api/auth/refresh");
        AuthResponse response = authService.refreshAccessToken(request);
        return ResponseEntity.ok(ApiResponse.success(response, "Token refreshed successfully"));
    }

    @PostMapping("/logout")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<ApiResponse<Void>> logout(
            @AuthenticationPrincipal String userId
    ) {
        log.info("POST /api/auth/logout - UserId: {}", userId);
        authService.logout(userId);
        return ResponseEntity.ok(ApiResponse.success(null, "Logged out successfully"));
    }

    // HEALTH CHECK

    @GetMapping("/health")
    public ResponseEntity<ApiResponse<String>> health() {
        return ResponseEntity.ok(ApiResponse.success("OK", "Auth service is running"));
    }
}
