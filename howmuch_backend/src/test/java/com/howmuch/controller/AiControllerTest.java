package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.ChatRequest;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.GeminiService;
import com.howmuch.service.SimpleRateLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class AiControllerTest {

    private GeminiService geminiService;
    private SimpleRateLimiter rateLimiter;
    private FirebaseService firebaseService;
    private AiController controller;
    private MockHttpServletRequest request;

    @BeforeEach
    void setUp() {
        geminiService = org.mockito.Mockito.spy(new GeminiService("", 1_000, false));
        rateLimiter = mock(SimpleRateLimiter.class);
        firebaseService = mock(FirebaseService.class);
        controller = new AiController(geminiService, rateLimiter, firebaseService);
        ReflectionTestUtils.setField(controller, "maxPerHour", 20);
        request = new MockHttpServletRequest();
    }

    @Test
    void rejectsMissingSessionBeforeRateLimiting() {
        ResponseEntity<?> response = controller.chat(
                ChatRequest.builder().message("안녕").build(), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(rateLimiter, geminiService, firebaseService);
    }

    @Test
    void rejectsNullBodyBeforeRateLimiting() {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");

        ResponseEntity<?> response = controller.chat(null, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(rateLimiter, geminiService, firebaseService);
    }

    @Test
    void resolvesNearbyStoresOnTheServerBeforeCallingGemini() {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        org.mockito.Mockito.when(rateLimiter.tryAcquire(org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyInt(), org.mockito.ArgumentMatchers.anyLong()))
                .thenReturn(true);
        java.util.List<java.util.Map<String, Object>> serverStores = java.util.List.of(
                java.util.Map.of("storeId", "store-1", "storeName", "검증된 매장", "source", "GOV",
                        "menu1", "짜장면", "price1", "5000", "distanceMeters", 300));
        org.mockito.Mockito.when(firebaseService.getAiStoreContext(
                java.util.List.of("store-1"), 37.5, 127.0, 3000)).thenReturn(serverStores);
        org.mockito.Mockito.doReturn("추천 결과입니다").when(geminiService).getAiResponse(
                org.mockito.ArgumentMatchers.eq("짜장면"),
                org.mockito.ArgumentMatchers.anyList(),
                org.mockito.ArgumentMatchers.anyList());

        ChatRequest chatReq = ChatRequest.builder()
                .message("짜장면")
                .history(java.util.List.of(java.util.Map.of("role", "user", "text", "안녕")))
                .nearbyStoreIds(java.util.List.of("store-1"))
                .latitude(37.5)
                .longitude(127.0)
                .build();

        ResponseEntity<?> response = controller.chat(chatReq, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        org.mockito.Mockito.verify(firebaseService).getAiStoreContext(
                chatReq.getNearbyStoreIds(), chatReq.getLatitude(), chatReq.getLongitude(), 3000);
        org.mockito.Mockito.verify(geminiService).getAiResponse(
                org.mockito.ArgumentMatchers.eq("짜장면"),
                org.mockito.ArgumentMatchers.eq(chatReq.getHistory()),
                org.mockito.ArgumentMatchers.argThat(context -> context.size() == 1
                        && "store-1".equals(context.get(0).get("storeId"))
                        && "짜장면".equals(context.get(0).get("menu1"))));
    }

    @Test
    void replacesGeminiFailureWithVerifiedNearbyStoreFallback() {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        when(rateLimiter.tryAcquire(org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyInt(), org.mockito.ArgumentMatchers.anyLong()))
                .thenReturn(true);
        java.util.List<java.util.Map<String, Object>> serverStores = java.util.List.of(
                java.util.Map.of(
                        "storeName", "검증된 식당",
                        "storeId", "store-1",
                        "menu1", "김치찌개",
                        "price1", "8,000",
                        "distanceMeters", 250));
        when(firebaseService.getAiStoreContext(java.util.List.of("store-1"), 37.5, 127.0, 3000))
                .thenReturn(serverStores);
        org.mockito.Mockito.doReturn("죄송합니다. AI 응답을 가져오는 중 오류가 발생했습니다.")
                .when(geminiService).getAiResponse(
                org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.anyList());

        ResponseEntity<?> response = controller.chat(ChatRequest.builder()
                .message("만원 이하 점심")
                .nearbyStoreIds(java.util.List.of("store-1"))
                .latitude(37.5)
                .longitude(127.0)
                .build(), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        com.howmuch.dto.ChatResponse body = (com.howmuch.dto.ChatResponse) response.getBody();
        assertThat(body.getResponse()).contains("검증된 식당");
        assertThat(body.isFallback()).isTrue();
        assertThat(body.getRecommendedStoreIds()).containsExactly("store-1");
        assertThat(body.getRecommendations().get(0)).containsEntry("matchedMenu", "김치찌개");
        assertThat(body.getRadiusMeters()).isEqualTo(3000);
    }

    @Test
    void rejectsOversizedHistoryBeforeRateLimiting() {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        java.util.List<java.util.Map<String, String>> history = java.util.stream.IntStream.range(0, 7)
                .mapToObj(index -> java.util.Map.of("role", "user", "text", "메시지" + index))
                .toList();

        ResponseEntity<?> response = controller.chat(ChatRequest.builder()
                .message("추천해줘")
                .history(history)
                .build(), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(rateLimiter, geminiService, firebaseService);
    }

    @Test
    void rejectsInvalidRadiusBeforeConsumingRateLimit() {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        for (int radius : java.util.List.of(0, 999, 1500, 16000)) {
            assertThat(controller.chat(ChatRequest.builder().message("국물 추천")
                    .latitude(37.5).longitude(127.0).radiusMeters(radius).build(), request)
                    .getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        }
        verifyNoInteractions(rateLimiter, geminiService, firebaseService);
    }

    @Test
    void missingLocationCannotProduceUnverifiedNearbyRecommendations() {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        assertThat(controller.chat(ChatRequest.builder().message("국물 추천").build(), request)
                .getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(rateLimiter, geminiService, firebaseService);
    }

    @Test
    void successfulProviderProseCannotAttachAStoreThatFailedSoupOrRadiusConstraints() {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        when(rateLimiter.tryAcquire(org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.anyInt(), org.mockito.ArgumentMatchers.anyLong())).thenReturn(true);
        var candidates = java.util.List.<java.util.Map<String, Object>>of(
                java.util.Map.of("storeId", "wrong", "storeName", "맛집", "menu1", "김밥", "price1", "3000", "distanceMeters", 100),
                java.util.Map.of("storeId", "far", "storeName", "원거리", "menu1", "국밥", "price1", "6000", "distanceMeters", 244800),
                java.util.Map.of("storeId", "good", "storeName", "동네식당", "menu1", "백반", "price1", "7000",
                        "menu2", "김치찌개", "price2", "8000", "distanceMeters", 900));
        when(firebaseService.getAiStoreContext(null, 37.5, 127.0, 1000)).thenReturn(candidates);
        org.mockito.Mockito.doReturn("맛집과 원거리 김밥이 조건을 만족해요").when(geminiService)
                .getAiResponse(org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.any(),
                        org.mockito.ArgumentMatchers.anyList());
        var response = controller.chat(ChatRequest.builder().message("만원 이하 국물 추천 세 곳")
                .latitude(37.5).longitude(127.0).radiusMeters(1000).build(), request);
        com.howmuch.dto.ChatResponse body = (com.howmuch.dto.ChatResponse) response.getBody();
        assertThat(body.isFallback()).isFalse();
        assertThat(body.getRecommendedStoreIds()).containsExactly("good");
        assertThat(body.getResponse()).contains("1곳", "김치찌개").doesNotContain("맛집", "원거리", "김밥");
        assertThat(body.getRecommendations().get(0)).containsEntry("menuIndex", 2);
    }
}
