package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.ChatRequest;
import com.howmuch.dto.ChatResponse;
import com.howmuch.service.GeminiService;
import com.howmuch.service.SimpleRateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
public class AiController {

    private final GeminiService geminiService;
    private final SimpleRateLimiter rateLimiter;

    /** 유저당 시간당 최대 AI 채팅 호출 횟수 (비용 악용 방지) */
    @Value("${ai.chat.max-per-hour:20}")
    private int maxPerHour;

    @PostMapping("/chat")
    public ResponseEntity<?> chat(@RequestBody ChatRequest request,
                                  HttpServletRequest httpRequest) {
        String uid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);

        // 💡 레이트리밋: 로그인 유저라도 무제한 호출은 AI API 비용 악용 위험
        String key = uid != null ? uid : "anonymous";
        if (!rateLimiter.tryAcquire(key, maxPerHour, 3_600_000L)) {
            return ResponseEntity.status(429).body(Map.of(
                    "success", false,
                    "message", "AI 채팅은 시간당 " + maxPerHour + "회까지 이용할 수 있습니다. 잠시 후 다시 시도해주세요."
            ));
        }

        String message = request.getMessage();
        if (message == null || message.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "message는 필수입니다."
            ));
        }
        // 💡 과도한 입력 길이 제한 (토큰 비용 방어)
        if (message.length() > 1000) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "메시지는 1000자 이내로 입력해주세요."
            ));
        }

        String aiResponse = geminiService.getAiResponse(message);
        return ResponseEntity.ok(new ChatResponse(aiResponse));
    }
}
