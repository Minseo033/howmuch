package com.howmuch.controller;

import com.howmuch.dto.KakaoAuthRequest;
import com.howmuch.service.AuthService;
import com.howmuch.service.SessionTokenService;
import com.howmuch.service.SessionRevocationStore;
import com.howmuch.service.SimpleRateLimiter;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.Arrays;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;

class AuthControllerTest {

    @Test
    void marksTheProductionConstructorForSpringInjection() {
        long autowiredConstructors = Arrays.stream(AuthController.class.getDeclaredConstructors())
                .filter(constructor -> constructor.isAnnotationPresent(Autowired.class))
                .count();

        assertEquals(1, autowiredConstructors);
    }

    @Test
    void rejectsMissingAccessTokenBeforeCallingExternalServices() {
        AuthService authService = mock(AuthService.class);
        SessionTokenService tokenService = mock(SessionTokenService.class);
        SimpleRateLimiter rateLimiter = mock(SimpleRateLimiter.class);
        AuthController controller = new AuthController(authService, tokenService, rateLimiter);
        KakaoAuthRequest request = new KakaoAuthRequest();

        ResponseEntity<?> response = controller.authenticateKakao(
                request, new MockHttpServletRequest());

        assertEquals(400, response.getStatusCode().value());
        verifyNoInteractions(authService, tokenService, rateLimiter);
    }

    @Test
    void sessionStoreFailureDuringLoginIsRetryableInsteadOfInvalidCredentials() throws Exception {
        AuthService authService = mock(AuthService.class);
        SessionTokenService tokens = mock(SessionTokenService.class);
        SimpleRateLimiter limiter = mock(SimpleRateLimiter.class);
        when(limiter.tryAcquire(anyString(), anyInt(), anyLong())).thenReturn(true);
        when(authService.authenticateKakao("valid-kakao-token"))
                .thenReturn(new AuthService.KakaoAuthResult("user-1", "firebase-token", "", ""));
        when(tokens.createToken("user-1"))
                .thenThrow(mock(SessionRevocationStore.UnavailableException.class));
        KakaoAuthRequest request = new KakaoAuthRequest();
        request.setKakaoAccessToken("valid-kakao-token");

        var response = new AuthController(authService, tokens, limiter)
                .authenticateKakao(request, new MockHttpServletRequest());

        assertEquals(503, response.getStatusCode().value());
        assertEquals("5", response.getHeaders().getFirst("Retry-After"));
    }
}
