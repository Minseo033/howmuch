package com.howmuch.controller;

import com.howmuch.dto.ChatRequest;
import com.howmuch.dto.ChatResponse;
import com.howmuch.service.GeminiService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
public class AiController {

    private final GeminiService geminiService;

    @PostMapping("/chat")
    public ResponseEntity<ChatResponse> chat(@RequestBody ChatRequest request) {
        String aiResponse = geminiService.getAiResponse(request.getMessage());
        return ResponseEntity.ok(new ChatResponse(aiResponse));
    }
}
