package com.howmuch.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class GeminiService {

    // 💡 보안: Gemini API 키는 환경변수(GEMINI_API_KEY)로만 주입합니다 (레포 public — 하드코딩 금지)
    private final String geminiApiKey;
    private final String geminiModel = "gemini-2.5-flash-lite"; // 사용자가 요청한 최신 2.5 Flash-Lite 모델
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public GeminiService(@Value("${gemini.api-key:}") String geminiApiKey,
                         @Value("${gemini.timeout-ms:10000}") int timeoutMs) {
        this.geminiApiKey = geminiApiKey;
        // 💡 외부 AI 호출 타임아웃 — 지연 시 요청 스레드 고갈 방지
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(timeoutMs);
        factory.setReadTimeout(timeoutMs);
        this.restTemplate = new RestTemplate(factory);
    }

    public String getAiResponse(String userMessage) {
        if (geminiApiKey == null || geminiApiKey.isBlank()) {
            log.warn("GEMINI_API_KEY 미설정 — AI 응답 불가");
            return "AI 기능이 현재 설정되지 않았습니다. 관리자에게 문의해주세요.";
        }
        // 💡 2.5 모델을 지원하는 v1beta 엔드포인트를 사용합니다.
        String url = "https://generativelanguage.googleapis.com/v1beta/models/" + geminiModel + ":generateContent?key=" + geminiApiKey;

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            // Gemini API 요청 규격 구성
            Map<String, Object> requestBody = Map.of(
                "contents", List.of(
                    Map.of("parts", List.of(
                        Map.of("text", userMessage)
                    ))
                )
            );

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);
            ResponseEntity<String> response = restTemplate.postForEntity(url, entity, String.class);

            JsonNode root = objectMapper.readTree(response.getBody());
            return root.path("candidates").get(0)
                    .path("content").path("parts").get(0)
                    .path("text").asText();

        } catch (Exception e) {
            // 💡 날부 에러 상세(e.getMessage())는 로그에만 남기고, 클라이언트에는 일반 메시지만 반환
            log.error("Gemini API 호출 중 오류 발생: ", e);
            return "죄송합니다. AI 응답을 가져오는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.";
        }
    }
}
