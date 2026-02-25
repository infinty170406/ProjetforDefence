package com.example.the_guardian_v1.service;

import com.example.the_guardian_v1.dto.execute.ExecuteRequest;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class GeminiService {

    @Value("${google.api.key}")
    private String apiKey;

    private final ObjectMapper objectMapper;
    private final RestTemplate restTemplate = new RestTemplate();

    private static final String GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=";

    public ExecuteRequest translateToIntent(String prompt, String childId) {
        String systemPrompt = """
                You are 'The Guardian' AI Orchestrator.
                Translate parent requests into backend commands for a parental control system.

                Valid Intents:
                1. UPSERT_CONTENT_POLICY: Category (ADULT, VIOLENCE, GAMBLING, SOCIAL, GAMES, STREAMING), Action (BLOCK, ALLOW), Keywords (list).
                2. CREATE_SCHEDULE: Days (MONDAY, etc.), StartTime/EndTime (HH:mm), Action (ALLOW, BLOCK).
                3. UPDATE_PROFILE: Mode (STRICT, MODERATE, PERMISSIVE), Enabled (true/false).

                Return ONLY a JSON object compatible with the backend `ExecuteRequest` parameters.
                Schema:
                {
                  "intent": "INTENT_NAME",
                  "parameters": { ... specific params for intent ... }
                }
                """;

        Map<String, Object> body = Map.of(
                "contents", List.of(
                        Map.of("role", "user", "parts",
                                List.of(Map.of("text", systemPrompt + "\\n\\nRequest: " + prompt)))),
                "generationConfig", Map.of(
                        "response_mime_type", "application/json"));

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);

        try {
            log.info("Calling Gemini for prompt: {}", prompt);
            Map<String, Object> response = restTemplate.postForObject(GEMINI_URL + apiKey, entity, Map.class);

            // Extract JSON from Gemini response
            List<Map<String, Object>> candidates = (List<Map<String, Object>>) response.get("candidates");
            Map<String, Object> content = (Map<String, Object>) candidates.get(0).get("content");
            List<Map<String, Object>> parts = (List<Map<String, Object>>) content.get("parts");
            String jsonText = (String) parts.get(0).get("text");

            ExecuteRequest intentRequest = objectMapper.readValue(jsonText, ExecuteRequest.class);
            intentRequest.requestId = UUID.randomUUID().toString();
            intentRequest.childId = childId;
            intentRequest.source = "GEMINI_AI";

            return intentRequest;
        } catch (Exception e) {
            log.error("Gemini translation failed", e);
            throw new RuntimeException("AI Orchestration failed: " + e.getMessage());
        }
    }
}
