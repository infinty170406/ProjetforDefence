package com.example.the_guardian_v1.controller;

import com.example.the_guardian_v1.dto.location.CreateGeofenceRequest;
import com.example.the_guardian_v1.dto.location.GeofenceDto;
import com.example.the_guardian_v1.service.location.GeofenceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * CRUD for circular geofences.
 *
 * All routes are authenticated (JWT required).
 * Ownership is enforced inside GeofenceService.
 *
 * POST /api/geofences
 * GET /api/geofences
 * GET /api/geofences/{id}
 * PATCH /api/geofences/{id}/activate
 * PATCH /api/geofences/{id}/deactivate
 * DELETE /api/geofences/{id}
 */
@RestController
@RequestMapping("/api/geofences")
@RequiredArgsConstructor
public class GeofenceController {

    private final GeofenceService geofenceService;

    @PostMapping
    public ResponseEntity<GeofenceDto> create(
            @AuthenticationPrincipal String parentId,
            @Valid @RequestBody CreateGeofenceRequest req) {
        GeofenceDto created = geofenceService.create(parentId, req);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    @GetMapping
    public ResponseEntity<List<GeofenceDto>> list(
            @AuthenticationPrincipal String parentId) {
        return ResponseEntity.ok(geofenceService.listByParent(parentId));
    }

    @GetMapping("/{id}")
    public ResponseEntity<GeofenceDto> getById(
            @AuthenticationPrincipal String parentId,
            @PathVariable Long id) {
        return ResponseEntity.ok(geofenceService.getById(parentId, id));
    }

    @PatchMapping("/{id}/activate")
    public ResponseEntity<GeofenceDto> activate(
            @AuthenticationPrincipal String parentId,
            @PathVariable Long id) {
        return ResponseEntity.ok(geofenceService.setActive(parentId, id, true));
    }

    @PatchMapping("/{id}/deactivate")
    public ResponseEntity<GeofenceDto> deactivate(
            @AuthenticationPrincipal String parentId,
            @PathVariable Long id) {
        return ResponseEntity.ok(geofenceService.setActive(parentId, id, false));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal String parentId,
            @PathVariable Long id) {
        geofenceService.delete(parentId, id);
        return ResponseEntity.noContent().build();
    }
}
