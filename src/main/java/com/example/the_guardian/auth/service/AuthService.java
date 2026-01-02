package com.example.the_guardian.auth.service;

import com.example.the_guardian.auth.dto.request.*;
import com.example.the_guardian.auth.dto.response.AuthResponse;
import com.example.the_guardian.auth.dto.response.ChildDto;
import com.example.the_guardian.auth.dto.response.UserInfo;
import com.example.the_guardian.auth.entity.*;
import com.example.the_guardian.auth.repository.*;
import com.example.the_guardian.auth.security.JwtService;
import com.example.the_guardian.auth.exception.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final ParentRepository parentRepository;
    private final ChildRepository childRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    // PARENT AUTHENTICATION

    @Transactional
    public AuthResponse registerParent(ParentRegisterRequest request) {
        log.info("Registering new parent with email: {}", request.getEmail());

        if (parentRepository.existsByEmail(request.getEmail())) {
            throw new BadRequestException("Email already registered");
        }

        Parent parent = Parent.builder()
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .firstName(request.getFirstName())
                .lastName(request.getLastName())
                .phoneNumber(request.getPhoneNumber())
                .role(Role.PARENT)
                .active(true)
                .emailVerified(false)
                .build();

        parent = parentRepository.save(parent);
        log.info("Parent registered successfully with ID: {}", parent.getId());

        return generateAuthResponse(parent.getId(), Role.PARENT.name(), parent);
    }

    @Transactional
    public AuthResponse loginParent(LoginRequest request) {
        log.info("Parent login attempt: {}", request.getEmail());

        Parent parent = parentRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new BadRequestException("Invalid credentials"));

        if (!passwordEncoder.matches(request.getPassword(), parent.getPassword())) {
            throw new BadRequestException("Invalid credentials");
        }

        if (!parent.getActive()) {
            throw new BadRequestException("Account is deactivated");
        }

        log.info("Parent logged in successfully: {}", parent.getId());
        return generateAuthResponse(parent.getId(), Role.PARENT.name(), parent);
    }

    // CHILD AUTHENTICATION

    @Transactional
    public AuthResponse loginChild(ChildLoginRequest request) {
        log.info("Child login attempt with ID: {}", request.getChildId());

        Child child = childRepository.findById(request.getChildId())
                .orElseThrow(() -> new ResourceNotFoundException("Child not found"));

        if (!child.getActive()) {
            throw new BadRequestException("Child account is deactivated");
        }

        // Associate device ID if not already set
        if (child.getDeviceId() == null || child.getDeviceId().isEmpty()) {
            child.setDeviceId(request.getDeviceId());
            childRepository.save(child);
            log.info("Device ID assigned to child: {}", child.getId());
        } else if (!child.getDeviceId().equals(request.getDeviceId())) {
            throw new BadRequestException("Device ID mismatch");
        }

        log.info("Child logged in successfully: {}", child.getId());
        return generateAuthResponse(child.getId(), Role.CHILD.name(), null);
    }

    // CHILD MANAGEMENT

    @Transactional
    public ChildDto addChild(String parentId, AddChildRequest request) {
        log.info("Adding new child for parent: {}", parentId);

        Parent parent = parentRepository.findById(parentId)
                .orElseThrow(() -> new ResourceNotFoundException("Parent not found"));

        Child child = Child.builder()
                .firstName(request.getFirstName())
                .lastName(request.getLastName())
                .age(request.getAge())
                .parent(parent)
                .role(Role.CHILD)
                .active(true)
                .build();

        child = childRepository.save(child);
        log.info("Child added successfully with ID: {}", child.getId());

        return mapToChildDto(child);
    }

    @Transactional(readOnly = true)
    public List<ChildDto> getChildren(String parentId) {
        return childRepository.findByParentIdAndActiveTrue(parentId).stream()
                .map(this::mapToChildDto)
                .collect(Collectors.toList());
    }


    @Transactional
    public AuthResponse refreshAccessToken(RefreshTokenRequest request) {
        String token = request.getRefreshToken();

        if (!jwtService.validateToken(token)) {
            throw new BadRequestException("Invalid refresh token");
        }

        RefreshToken refreshToken = refreshTokenRepository.findByToken(token)
                .orElseThrow(() -> new BadRequestException("Refresh token not found"));

        if (refreshToken.getRevoked()) {
            throw new BadRequestException("Refresh token has been revoked");
        }

        if (refreshToken.getExpiryDate().isBefore(LocalDateTime.now())) {
            throw new BadRequestException("Refresh token has expired");
        }

        String userId = refreshToken.getUserId();
        String role = refreshToken.getUserRole().name();

        String newAccessToken = jwtService.generateAccessToken(userId, role);

        return AuthResponse.builder()
                .accessToken(newAccessToken)
                .refreshToken(token)
                .tokenType("Bearer")
                .expiresIn(jwtService.getAccessTokenExpiration())
                .build();
    }

    @Transactional
    public void logout(String userId) {
        List<RefreshToken> tokens = refreshTokenRepository.findByUserIdAndRevokedFalse(userId);
        tokens.forEach(token -> token.setRevoked(true));
        refreshTokenRepository.saveAll(tokens);
        log.info("User logged out successfully: {}", userId);
    }


    private AuthResponse generateAuthResponse(String userId, String role, Parent parent) {
        String accessToken = jwtService.generateAccessToken(userId, role);
        String refreshToken = jwtService.generateRefreshToken(userId, role);

        // Save refresh token
        RefreshToken refreshTokenEntity = RefreshToken.builder()
                .token(refreshToken)
                .userId(userId)
                .userRole(Role.valueOf(role))
                .expiryDate(LocalDateTime.now().plusDays(7))
                .revoked(false)
                .build();

        refreshTokenRepository.save(refreshTokenEntity);

        UserInfo userInfo = null;
        if (parent != null) {
            userInfo = UserInfo.builder()
                    .id(parent.getId())
                    .email(parent.getEmail())
                    .firstName(parent.getFirstName())
                    .lastName(parent.getLastName())
                    .role(role)
                    .children(parent.getChildren().stream()
                            .map(this::mapToChildDto)
                            .collect(Collectors.toList()))
                    .build();
        }

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(jwtService.getAccessTokenExpiration())
                .user(userInfo)
                .build();
    }

    private ChildDto mapToChildDto(Child child) {
        return ChildDto.builder()
                .id(child.getId())
                .firstName(child.getFirstName())
                .lastName(child.getLastName())
                .age(child.getAge())
                .deviceId(child.getDeviceId())
                .active(child.getActive())
                .createdAt(child.getCreatedAt())
                .build();
    }
}