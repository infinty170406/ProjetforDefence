package com.example.the_guardian_v1.controller;

import com.example.the_guardian_v1.dto.ai.AiCommandRequest;
import com.example.the_guardian_v1.dto.execute.ExecuteRequest;
import com.example.the_guardian_v1.dto.execute.ExecuteResponse;
import com.example.the_guardian_v1.service.GeminiService;
import com.example.the_guardian_v1.service.IExecuteService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequestMapping("/api/v1/ai")
@RequiredArgsConstructor
public class AiController {

    private final GeminiService geminiService;
    private final IExecuteService executeService;

    @PostMapping("/command")
    public ExecuteResponse processCommand(@Valid @RequestBody AiCommandRequest request) {
        log.info("Received AI command request for child: {}", request.getChildId());

        // 1. Translate prompt to executable intent via Gemini
        ExecuteRequest executableIntent = geminiService.translateToIntent(request.getPrompt(), request.getChildId());

        // 2. Execute the intent on the backend
        return executeService.execute(executableIntent);
    }
}
