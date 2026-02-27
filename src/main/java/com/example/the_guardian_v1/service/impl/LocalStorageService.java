package com.example.the_guardian_v1.service.impl;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;

/**
 * Local filesystem implementation of file storage.
 * Replaces SupabaseStorageService — no external dependency.
 * Files are written to {@code app.storage.base-dir} (default: /data/kyc).
 */
@Service
@Slf4j
public class LocalStorageService {

    private final String baseDir;

    public LocalStorageService(@Value("${app.storage.base-dir:/data/kyc}") String baseDir) {
        this.baseDir = baseDir;
    }

    /**
     * Persists {@code file} at {@code relativePath} under the configured base
     * directory.
     *
     * @param relativePath e.g. "uid/kyc/document_123_id.jpg"
     * @param file         the multipart file to store
     * @return the relative path that was used (can be stored in DB for later
     *         retrieval)
     */
    public String uploadFile(String relativePath, MultipartFile file) {
        try {
            Path destination = Paths.get(baseDir, relativePath).normalize();
            Files.createDirectories(destination.getParent());
            Files.copy(file.getInputStream(), destination, StandardCopyOption.REPLACE_EXISTING);
            log.info("File saved locally: {}", destination);
            return relativePath;
        } catch (IOException e) {
            log.error("Failed to save file locally at {}: {}", relativePath, e.getMessage());
            throw new RuntimeException("Local storage error", e);
        }
    }

    /**
     * Returns a server-relative URL path for the file.
     * Suitable for logging / DB reference; not a signed URL.
     *
     * @param relativePath     the path returned by {@link #uploadFile}
     * @param expiresInSeconds ignored (local storage has no expiry)
     * @return a path string that can be used to build a download URL if needed
     */
    public String getSignedUrl(String relativePath, int expiresInSeconds) {
        return "/files/" + relativePath;
    }
}
