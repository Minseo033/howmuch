package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import com.howmuch.service.GeminiService;
import com.howmuch.service.SimpleRateLimiter;
import com.howmuch.service.WeatherService;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** 계약 C5(날씨 실패에도 추천 반환)·FE-STORE-13(루트 순서) */
class RecommendationControllerWeatherFallbackTest {
    private final WeatherService weatherService = mock(WeatherService.class);
    private final FirebaseService firebaseService = mock(FirebaseService.class);
    private final GeminiService geminiService = mock(GeminiService.class);
    private final SimpleRateLimiter rateLimiter = mock(SimpleRateLimiter.class);
    private final RecommendationController controller =
            new RecommendationController(weatherService, firebaseService, geminiService, rateLimiter);
    private final List<Map<String, Object>> picks = List.of(Map.of("storeId", "a"), Map.of("storeId", "b"));

    @Test
    void todaysPickStillReturnsRecommendationsWhenWeatherFails() {
        when(weatherService.getCurrentWeather(37.5, 127.0)).thenThrow(new IllegalStateException("timeout"));
        when(firebaseService.getTodaysPicks(eq("알 수 없음"), eq(null), eq(37.5), eq(127.0), anyInt())).thenReturn(picks);

        ResponseEntity<?> response = controller.getTodaysPick(37.5, 127.0, null);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        Map<?, ?> body = (Map<?, ?>) response.getBody();
        assertThat(body.get("picks")).isEqualTo(picks);
        assertThat(body.get("weatherAvailable")).isEqualTo(false);
    }

    @Test
    void routeUsesTheShortestVisitOrderAndSurvivesWeatherFailure() {
        when(rateLimiter.tryAcquire(anyString(), anyInt(), anyLong())).thenReturn(true);
        when(weatherService.getCurrentWeather(37.5, 127.0)).thenThrow(new IllegalStateException("timeout"));
        when(firebaseService.getTodaysPicks(eq("알 수 없음"), eq(null), eq(37.5), eq(127.0), anyInt())).thenReturn(picks);
        List<Map<String, Object>> reordered = List.of(picks.get(1), picks.get(0));
        when(firebaseService.orderRouteStops(picks, 37.5, 127.0)).thenReturn(reordered);
        when(geminiService.getRouteRecommendation(reordered)).thenReturn("b → a");

        ResponseEntity<?> response = controller.getRoute(37.5, 127.0, null, new MockHttpServletRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        Map<?, ?> body = (Map<?, ?>) response.getBody();
        assertThat(body.get("picks")).isEqualTo(reordered);
        assertThat(body.get("route")).isEqualTo("b → a");
        assertThat(body.get("weatherAvailable")).isEqualTo(false);
    }
}

