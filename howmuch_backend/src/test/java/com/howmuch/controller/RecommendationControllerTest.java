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
    void rejectsMissingCoordinatesInsteadOfUsingASeoulDefault() {
        ResponseEntity<?> response = controller.getTodaysPick(null, null);

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

    @Test
    void rejectsInvalidRadiusBeforeWeatherOrRateLimitCalls() {
        for (int radius : java.util.List.of(0, 999, 1500, 16000)) {
            assertThat(controller.getTodaysPick(37.5, 127.0, radius).getStatusCode())
                    .isEqualTo(HttpStatus.BAD_REQUEST);
            assertThat(controller.getRoute(37.5, 127.0, radius, new MockHttpServletRequest()).getStatusCode())
                    .isEqualTo(HttpStatus.BAD_REQUEST);
        }
        verifyNoInteractions(weatherService, firebaseService, geminiService, rateLimiter);
    }

    @Test
    void todaysPickPassesTheSelectedRadiusToCanonicalStoreService() {
        org.mockito.Mockito.when(weatherService.getCurrentWeather(37.5, 127.0))
                .thenReturn(java.util.Map.of("weather", "비", "temp", 20));
        org.mockito.Mockito.when(firebaseService.getTodaysPicks("비", 20, 37.5, 127.0, 15000))
                .thenReturn(java.util.List.of());
        var response = controller.getTodaysPick(37.5, 127.0, 15000);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(((java.util.Map<?, ?>) response.getBody()).get("radiusMeters")).isEqualTo(15000);
        org.mockito.Mockito.verify(firebaseService).getTodaysPicks("비", 20, 37.5, 127.0, 15000);
    }
}
