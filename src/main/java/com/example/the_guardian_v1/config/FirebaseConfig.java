package com.example.the_guardian_v1.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;

import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.InputStream;
import java.util.Base64;

@Configuration
@Slf4j
public class FirebaseConfig {

    @Value("${firebase.service-account-path:}")
    private String serviceAccountPath;

    @Value("${firebase.service-account-json:}")
    private String serviceAccountJson;

    @PostConstruct
    public void initFirebase() {
        if (!FirebaseApp.getApps().isEmpty()) {
            log.info("FirebaseApp already initialized, skipping.");
            return;
        }
        try {
            InputStream serviceAccount = resolveCredentials();
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();
            FirebaseApp.initializeApp(options);
            log.info("Firebase Admin SDK initialized successfully.");
        } catch (Exception e) {
            // Allow startup even without Firebase (e.g. local dev without credentials)
            // Any protected endpoint will simply return 401.
            log.error("Failed to initialize Firebase Admin SDK: {}. " +
                    "Set FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_SERVICE_ACCOUNT_JSON.", e.getMessage());
        }
    }

    private InputStream resolveCredentials() throws Exception {
        // 1. Try path to JSON file
        if (StringUtils.hasText(serviceAccountPath)) {
            log.info("Loading Firebase credentials from path: {}", serviceAccountPath);
            return new FileInputStream(serviceAccountPath);
        }
        // 2. Try base64-encoded JSON string (for Render / CI)
        if (StringUtils.hasText(serviceAccountJson)) {
            log.info("Loading Firebase credentials from base64-encoded env var.");
            byte[] decoded = Base64.getDecoder().decode(serviceAccountJson);
            return new ByteArrayInputStream(decoded);
        }
        throw new IllegalStateException(
                "No Firebase credentials configured. " +
                        "Set FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_SERVICE_ACCOUNT_JSON.");
    }
}
