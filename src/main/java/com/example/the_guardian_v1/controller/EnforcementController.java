package com.example.the_guardian_v1.controller;

import com.example.the_guardian_v1.service.IParentalService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/enforcement")
@RequiredArgsConstructor
public class EnforcementController {

    private final IParentalService parentalService;

    @PostMapping("/violation/{childId}")
    public void logViolation(@PathVariable String childId, @RequestBody ViolationRequest request) {
        parentalService.logViolation(childId, request.getTitle(), request.getMessage(), request.getType());
    }

    @Data
    public static class ViolationRequest {
        private String title;
        private String message;
        private String type; // e.g., SCREEN_TIME_EXCEEDED, APP_BLOCKED
    }
}
