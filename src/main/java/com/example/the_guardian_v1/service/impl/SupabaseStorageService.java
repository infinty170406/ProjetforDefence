package com.example.the_guardian_v1.service.impl;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.util.HashMap;
import java.util.Map;

@Service
@Slf4j
public class SupabaseStorageService {

    private final RestTemplate restTemplate;
    private final String supabaseUrl;
    private final String supabaseKey;
    private final String bucketName;

    public SupabaseStorageService(
            RestTemplate restTemplate,
            @Value("${supabase.url}") String supabaseUrl,
            @Value("${supabase.anon-key}") String supabaseKey,
            @Value("${supabase.storage.bucket:guardian-files}") String bucketName) {
        this.restTemplate = restTemplate;
        this.supabaseUrl = supabaseUrl;
        this.supabaseKey = supabaseKey;
        this.bucketName = bucketName;
    }

    public String uploadFile(String path, MultipartFile file) {
        String url = String.format("%s/storage/v1/object/%s/%s", supabaseUrl, bucketName, path);

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setBearerAuth(supabaseKey);
            headers.set("apiKey", supabaseKey);
            String contentType = file.getContentType();
            headers.setContentType(MediaType.valueOf(contentType != null ? contentType : "application/octet-stream"));

            HttpEntity<byte[]> entity = new HttpEntity<>(file.getBytes(), headers);

            ResponseEntity<String> response = restTemplate.postForEntity(url, entity, String.class);

            if (response.getStatusCode().is2xxSuccessful()) {
                log.info("File uploaded successfully to Supabase: {}", path);
                return path;
            } else {
                log.error("Failed to upload file to Supabase: {}. Status: {}", path, response.getStatusCode());
                throw new RuntimeException("Supabase upload failed");
            }
        } catch (Exception e) {
            log.error("Error uploading file to Supabase: {}", e.getMessage());
            throw new RuntimeException("Storage error", e);
        }
    }

    public String getSignedUrl(String path, int expiresInSeconds) {
        String url = String.format("%s/storage/v1/object/sign/%s/%s", supabaseUrl, bucketName, path);

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setBearerAuth(supabaseKey);
            headers.set("apiKey", supabaseKey);
            headers.setContentType(MediaType.APPLICATION_JSON);

            Map<String, Object> body = new HashMap<>();
            body.put("expiresIn", expiresInSeconds);

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);

            ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                    url,
                    HttpMethod.POST,
                    entity,
                    new org.springframework.core.ParameterizedTypeReference<Map<String, Object>>() {
                    });
            Map<String, Object> responseBody = response.getBody();

            if (response.getStatusCode().is2xxSuccessful() && responseBody != null) {
                String signedPath = (String) responseBody.get("signedURL");
                return supabaseUrl + "/storage/v1" + signedPath;
            } else {
                log.error("Failed to get signed URL from Supabase: {}. Status: {}", path, response.getStatusCode());
                throw new RuntimeException("Supabase signed URL failed");
            }
        } catch (Exception e) {
            log.error("Error getting signed URL from Supabase: {}", e.getMessage());
            throw new RuntimeException("Storage error", e);
        }
    }
}
