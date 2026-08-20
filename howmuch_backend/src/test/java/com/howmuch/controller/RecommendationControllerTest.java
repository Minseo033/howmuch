package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import com.howmuch.service.GeminiService;
import com.howmuch.service.SimpleRateLimiter;
import com.howmuch.service.WeatherService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

class RecommendationControllerTest {

    private WeatherService weatherService;
    private FirebaseService firebaseService;
    private GeminiService geminiService;
    private SimpleRateLimiter rateLimiter;
    private RecommendationController controller;

    @BeforeEach
    void setUp() {
        weatherService = mock(WeatherService.class);
        firebaseService = mock(FirebaseService.class);
        geminiService = mock(GeminiService.class);
        rateLimiter = mock(SimpleRateLimiter.class);
        controller = new RecommendationController(
                weatherService, firebaseService, geminiService, rateLimiter);
    }

    @Test
    void rejectsAnIncompleteCoordinatePairBeforeCallingExternalServices() {
        ResponseEntity<?> response = controller.getTodaysPick(37.5, null);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(weatherService, firebaseService, geminiService, rateLimiter);
    }

    @Test
    void rejectsOutOfRangeRouteCoordinatesBeforeConsumingRateLimit() {
        ResponseEntity<?> response = controller.getRoute(
                91.0, 127.0, new MockHttpServletRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(weatherService, firebaseService, geminiService, rateLimiter);
    }
}
