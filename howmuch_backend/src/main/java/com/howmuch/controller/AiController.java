package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.ChatRequest;
import com.howmuch.dto.ChatResponse;
import com.howmuch.service.FirebaseService;
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
import java.util.List;

@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
public class AiController {

    private final GeminiService geminiService;
    private final SimpleRateLimiter rateLimiter;
    private final FirebaseService firebaseService;

    /** 유저당 시간당 최대 AI 채팅 호출 횟수 (비용 악용 방지) */
    @Value("${ai.chat.max-per-hour:20}")
    private int maxPerHour;

    @PostMapping("/chat")
    public ResponseEntity<?> chat(@RequestBody ChatRequest request,
                                  HttpServletRequest httpRequest) {
        String uid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);

        if (uid == null || uid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false, "message", "로그인이 필요합니다."));
        }
        if (request == null || request.getMessage() == null || request.getMessage().isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "message는 필수입니다."
            ));
        }
        String message = request.getMessage().trim();
        if (message.length() > 1000) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "메시지는 1000자 이내로 입력해주세요."
            ));
        }
        if (!isValidContext(request)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "AI 대화 정보 형식이 올바르지 않습니다."
            ));
        }

        // 💡 레이트리밋: 로그인 유저라도 무제한 호출은 AI API 비용 악용 위험
        if (!rateLimiter.tryAcquire("ai-chat:" + uid, maxPerHour, 3_600_000L)) {
            return ResponseEntity.status(429).body(Map.of(
                    "success", false,
                    "message", "AI 채팅은 시간당 " + maxPerHour + "회까지 이용할 수 있습니다. 잠시 후 다시 시도해주세요."
            ));
        }

        List<Map<String, Object>> nearbyStores = firebaseService.getAiStoreContext(
                request.getNearbyStoreIds(), request.getLatitude(), request.getLongitude());
        String aiResponse = geminiService.getAiResponse(message, request.getHistory(), nearbyStores);
        return ResponseEntity.ok(new ChatResponse(aiResponse));
    }

    private boolean isValidContext(ChatRequest request) {
        List<Map<String, String>> history = request.getHistory();
        if (history != null) {
            if (history.size() > 6) return false;
            for (Map<String, String> turn : history) {
                if (turn == null) return false;
                String role = turn.get("role");
                String text = turn.get("text");
                if (!("user".equals(role) || "model".equals(role))
                        || text == null || text.isBlank() || text.length() > 1000) {
                    return false;
                }
            }
        }

        List<String> storeIds = request.getNearbyStoreIds();
        if (storeIds != null) {
            if (storeIds.size() > 10) return false;
            for (String storeId : storeIds) {
                if (storeId == null || storeId.isBlank() || storeId.length() > 200) return false;
            }
        }

        Double lat = request.getLatitude();
        Double lng = request.getLongitude();
        return (lat == null && lng == null)
                || (lat != null && lng != null
                && Double.isFinite(lat) && Double.isFinite(lng)
                && lat >= -90 && lat <= 90
                && lng >= -180 && lng <= 180);
    }
}
