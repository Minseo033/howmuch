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
    private final boolean routeAiEnabled;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public GeminiService(@Value("${gemini.api-key:}") String geminiApiKey,
                         @Value("${gemini.timeout-ms:10000}") int timeoutMs,
                         @Value("${gemini.route-enabled:false}") boolean routeAiEnabled) {
        this.geminiApiKey = geminiApiKey;
        this.routeAiEnabled = routeAiEnabled;
        // 💡 외부 AI 호출 타임아웃 — 지연 시 요청 스레드 고갈 방지
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(timeoutMs);
        factory.setReadTimeout(timeoutMs);
        this.restTemplate = new RestTemplate(factory);
    }

    private static final List<String> CANDIDATE_URLS = List.of(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent",
        "https://generativelanguage.googleapis.com/v1/models/gemini-3.6-flash:generateContent",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
        "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    );
    private volatile String workingUrl = null;

    private static final String SYSTEM_INSTRUCTION = """
        당신은 고물가 시대 가성비 매장 탐색 서비스 '얼마고?'의 똑똑하고 친근한 AI 가이드입니다.
        다음 5대 행동 규칙을 반드시 지켜 답변하세요:

        1. [가성비 & 이웃 제보 중심]: 정부 인증 '착한가격업소'와 동네 이웃들이 직접 발굴한 '사용자 제보 가성비 매장'을 최우선으로 다룹니다. 1만원 이하 식사 및 알뜰 소비를 권장하세요.
        2. [모바일 간결성]: 스마트폰 화면에서 한눈에 들어오도록 핵심 정보([메뉴/매장 + 예상 가격대 + 추천 이유]) 위주로 간결하게 구성하세요.
        3. [위치 확인]: 사용자가 구체적인 지역(역명, 동명 등)을 언급하지 않았다면, 먼저 "어느 역이나 동 근처이신가요?"라고 1줄로 위치를 확인하세요.
        4. [앱 기능 연계]: 답변 끝에 상황에 맞게 1줄 팁을 자연스럽게 덧붙이세요.
           - 방문 후: "[방문 인증] 탭에서 영수증을 찍으면 절약 리포트에 바로 기록돼요!"
           - 매장 발견: "동네에 아는 숨은 갓성비 매장이 있다면 [제보하기]로 이웃들과 나눠보세요!"
        5. [도메인 집중]: 주식, 정치 등 서비스와 무관한 질문에는 "저는 고물가 시대 동네 가성비 지킴이 얼마고 AI예요!"라며 식비 절약 및 가성비 코스 탐색으로 부드럽게 유도하세요.
        """.strip();

    public String getAiResponse(String userMessage) {
        if (geminiApiKey == null || geminiApiKey.isBlank()) {
            log.warn("GEMINI_API_KEY 미설정 — AI 응답 불가");
            return "AI 기능이 현재 설정되지 않았습니다. 관리자에게 문의해주세요.";
        }

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("X-Goog-Api-Key", geminiApiKey);

        Map<String, Object> requestBody = Map.of(
            "system_instruction", Map.of(
                "parts", List.of(
                    Map.of("text", SYSTEM_INSTRUCTION)
                )
            ),
            "contents", List.of(
                Map.of("parts", List.of(
                    Map.of("text", userMessage)
                ))
            )
        );
        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);

        // 이미 확인된 정상 동작 엔드포인트가 있으면 우선 호출
        String cachedUrl = this.workingUrl;
        if (cachedUrl != null) {
            try {
                return callGemini(cachedUrl, entity);
            } catch (Exception e) {
                log.warn("캐시된 Gemini 엔드포인트({}) 호출 실패, 후보군 재탐색: {}", cachedUrl, e.getMessage());
                this.workingUrl = null;
            }
        }

        // 후보군 순회하며 작동하는 엔드포인트 자동 탐색
        Exception lastException = null;
        for (String url : CANDIDATE_URLS) {
            try {
                String result = callGemini(url, entity);
                this.workingUrl = url;
                log.info("Gemini 유효 엔드포인트 확인 및 저장: {}", url);
                return result;
            } catch (Exception e) {
                lastException = e;
                log.warn("Gemini 엔드포인트({}) 시도 실패: {}", url, e.getMessage());
            }
        }

        log.error("모든 Gemini 엔드포인트 호출 실패: {}", lastException != null ? lastException.getMessage() : "unknown");
        try {
            HttpHeaders probeHeaders = new HttpHeaders();
            probeHeaders.set("X-Goog-Api-Key", geminiApiKey);
            ResponseEntity<String> modelsRes = restTemplate.exchange(
                "https://generativelanguage.googleapis.com/v1beta/models",
                org.springframework.http.HttpMethod.GET,
                new HttpEntity<>(probeHeaders),
                String.class
            );
            log.info("[GeminiService] 사용 가능한 구글 모델 목록: {}", modelsRes.getBody());
        } catch (Exception ex) {
            log.warn("[GeminiService] ListModels 조회 실패: {}", ex.getMessage());
        }
        return "죄송합니다. AI 응답을 가져오는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.";
    }

    private String callGemini(String url, HttpEntity<Map<String, Object>> entity) throws Exception {
        ResponseEntity<String> response = restTemplate.postForEntity(url, entity, String.class);
        JsonNode root = objectMapper.readTree(response.getBody());
        return root.path("candidates").get(0)
                .path("content").path("parts").get(0)
                .path("text").asText();
    }

    /**
     * AI 루트 추천 — 오늘의 픽 매장 목록을 받아 최적 동선(식사→카페 등)을 추천.
     * Gemini에 매장 정보를 전달해 순서/이유를 받아온다.
     * @param picks 오늘의 픽 매장 목록 (storeName/menu1/price1/distanceMeters 포함)
     * @return AI 추천 루트 텍스트
     */
    public String getRouteRecommendation(List<Map<String, Object>> picks) {
        if (picks == null || picks.isEmpty()) {
            return "추천할 매장이 없습니다.";
        }
        // 구형/미검증 키가 설정되어 있어도 기본값에서는 외부 호출을 하지 않습니다.
        // 거리순 로컬 루트는 Gemini 없이도 지도와 함께 정상적으로 사용할 수 있습니다.
        if (!routeAiEnabled || geminiApiKey == null || geminiApiKey.isBlank()) {
            return buildLocalRouteRecommendation(picks);
        }

        StringBuilder sb = new StringBuilder();
        sb.append("다음은 오늘의 픽으로 선정된 착한가격업소 매장 목록입니다. ");
        sb.append("이 중에서 식사부터 카페까지 저렴한 동선(루트)을 추천해주세요. ");
        sb.append("각 매장의 순서와 이동 이유를 간결하게 한국어로 알려주세요. ");
        sb.append("응답은 '1. 매장명 (메뉴, 가격, 거리) - 이유' 형식으로 최대 3개까지만 나열해주세요.\n\n");
        for (int i = 0; i < picks.size(); i++) {
            Map<String, Object> p = picks.get(i);
            sb.append(i + 1).append(". ")
              .append(p.get("storeName")).append(" / ")
              .append(p.get("menu1")).append(" / ")
              .append(priceLabel(p.get("price1")));
            if (p.get("distanceMeters") != null) {
                sb.append(" / ").append(p.get("distanceMeters")).append("m");
            }
            sb.append("\n");
        }

        String aiResponse = getAiResponse(sb.toString());
        // Gemini is optional for this feature. An invalid/expired key must not
        // turn the whole route screen into an error state; keep the route usable
        // with the deterministic local ordering when the AI call fails.
        if (isAiFailureResponse(aiResponse)) {
            return buildLocalRouteRecommendation(picks);
        }
        return aiResponse;
    }

    private boolean isAiFailureResponse(String response) {
        if (response == null || response.isBlank()) return true;
        return response.contains("AI 기능이 현재 설정되지 않았습니다")
                || response.contains("AI 응답을 가져오지 못했습니다")
                || response.contains("AI 응답을 가져오는 중 오류")
                || response.contains("AI 연결에 실패했습니다");
    }

    private String buildLocalRouteRecommendation(List<Map<String, Object>> picks) {
        List<Map<String, Object>> sorted = picks.stream()
                .sorted((a, b) -> Double.compare(distanceOf(a), distanceOf(b)))
                .limit(3)
                .toList();

        StringBuilder result = new StringBuilder("현재는 거리순으로 추천 루트를 안내합니다.\n");
        for (int i = 0; i < sorted.size(); i++) {
            Map<String, Object> pick = sorted.get(i);
            result.append(i + 1).append(". ")
                    .append(pick.getOrDefault("storeName", "매장명 없음"))
                    .append(" (")
                    .append(pick.getOrDefault("menu1", "메뉴 정보 없음"))
                    .append(", ")
                    .append(priceLabel(pick.get("price1")))
                    .append(")");
            if (pick.get("distanceMeters") != null) {
                result.append(" - 현재 위치에서 가까운 순서");
            }
            result.append("\n");
        }
        return result.toString().trim();
    }

    private double distanceOf(Map<String, Object> pick) {
        Object value = pick.get("distanceMeters");
        if (value instanceof Number number) return number.doubleValue();
        try {
            return Double.parseDouble(String.valueOf(value));
        } catch (Exception e) {
            return Double.MAX_VALUE;
        }
    }

    private String priceLabel(Object value) {
        if (value == null || value.toString().isBlank()) return "가격 정보 없음";
        String label = value.toString().trim();
        return label.endsWith("원") ? label : label + "원";
    }
}
