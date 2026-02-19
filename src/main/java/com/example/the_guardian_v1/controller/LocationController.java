package com.example.the_guardian_v1.controller;

import com.example.the_guardian_v1.dto.location.LocationUpdateRequest;
import com.example.the_guardian_v1.dto.location.LocationUpdateResponse;
import com.example.the_guardian_v1.service.location.LocationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * POST /api/location/update
 *
 * Authenticated by JWT filter. The JWT subject (parentId) is injected via
 * 
 * @AuthenticationPrincipal — the JwtAuthFilter sets the principal to the
 *                          raw parentId string.
 */
@RestController
@RequestMapping("/api/location")
@RequiredArgsConstructor
public class LocationController {

    private final LocationService locationService;

    /**
     * Child-device calls this endpoint after each GPS fix.
     * The JWT in the Bearer header must belong to the parent who owns the child.
     *
     * @param parentId injected from Security context (JWT subject)
     * @param request  validated GPS payload
     */
    @PostMapping("/update")
    public ResponseEntity<LocationUpdateResponse> update(
            @AuthenticationPrincipal String parentId,
            @Valid @RequestBody LocationUpdateRequest request) {

        LocationUpdateResponse response = locationService.processUpdate(parentId, request);
        return ResponseEntity.ok(response);
    }
}
