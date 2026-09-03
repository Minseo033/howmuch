package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.ChatRequest;
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
    private AiController controller;
    private MockHttpServletRequest request;

    @BeforeEach
    void setUp() {
        geminiService = mock(GeminiService.class);
        rateLimiter = mock(SimpleRateLimiter.class);
        controller = new AiController(geminiService, rateLimiter);
        ReflectionTestUtils.setField(controller, "maxPerHour", 20);
        request = new MockHttpServletRequest();
    }

    @Test
    void rejectsMissingSessionBeforeRateLimiting() {
        ResponseEntity<?> response = controller.chat(
                ChatRequest.builder().message("안녕").build(), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(rateLimiter, geminiService);
    }

    @Test
    void rejectsNullBodyBeforeRateLimiting() {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");

        ResponseEntity<?> response = controller.chat(null, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(rateLimiter, geminiService);
    }

    @Test
    void forwardsHistoryAndNearbyStoresToGeminiService() {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        org.mockito.Mockito.when(rateLimiter.tryAcquire(org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyInt(), org.mockito.ArgumentMatchers.anyLong()))
                .thenReturn(true);
        org.mockito.Mockito.when(geminiService.getAiResponse(
                org.mockito.ArgumentMatchers.eq("짜장면"),
                org.mockito.ArgumentMatchers.anyList(),
                org.mockito.ArgumentMatchers.anyList()))
                .thenReturn("추천 결과입니다");

        ChatRequest chatReq = ChatRequest.builder()
                .message("짜장면")
                .history(java.util.List.of(java.util.Map.of("role", "user", "text", "안녕")))
                .nearbyStores(java.util.List.of(java.util.Map.of("storeName", "구구반점", "menu1", "짜장면", "price1", "5000")))
                .build();

        ResponseEntity<?> response = controller.chat(chatReq, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        org.mockito.Mockito.verify(geminiService).getAiResponse(
                org.mockito.ArgumentMatchers.eq("짜장면"),
                org.mockito.ArgumentMatchers.eq(chatReq.getHistory()),
                org.mockito.ArgumentMatchers.eq(chatReq.getNearbyStores()));
    }
}
