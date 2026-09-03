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

class AiControllerTest {

    private GeminiService geminiService;
    private SimpleRateLimiter rateLimiter;
    private FirebaseService firebaseService;
    private AiController controller;
    private MockHttpServletRequest request;

    @BeforeEach
    void setUp() {
        geminiService = mock(GeminiService.class);
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
                java.util.Map.of("storeName", "검증된 매장", "source", "착한가격업소"));
        org.mockito.Mockito.when(firebaseService.getAiStoreContext(
                java.util.List.of("store-1"), 37.5, 127.0)).thenReturn(serverStores);
        org.mockito.Mockito.when(geminiService.getAiResponse(
                org.mockito.ArgumentMatchers.eq("짜장면"),
                org.mockito.ArgumentMatchers.anyList(),
                org.mockito.ArgumentMatchers.anyList()))
                .thenReturn("추천 결과입니다");

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
                chatReq.getNearbyStoreIds(), chatReq.getLatitude(), chatReq.getLongitude());
        org.mockito.Mockito.verify(geminiService).getAiResponse(
                org.mockito.ArgumentMatchers.eq("짜장면"),
                org.mockito.ArgumentMatchers.eq(chatReq.getHistory()),
                org.mockito.ArgumentMatchers.eq(serverStores));
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
}
