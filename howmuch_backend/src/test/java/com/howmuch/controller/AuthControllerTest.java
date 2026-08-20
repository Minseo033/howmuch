package com.howmuch.controller;

import com.howmuch.dto.KakaoAuthRequest;
import com.howmuch.service.AuthService;
import com.howmuch.service.SessionTokenService;
import com.howmuch.service.SimpleRateLimiter;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

class AuthControllerTest {

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
}
