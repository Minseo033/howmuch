package com.howmuch.controller;

import com.howmuch.dto.FirebaseTokenResponse;
import com.howmuch.dto.KakaoAuthRequest;
import com.howmuch.service.AuthService;
import com.howmuch.service.SessionTokenService;
import com.howmuch.service.SimpleRateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;
    private final SessionTokenService sessionTokenService;
    private final SimpleRateLimiter rateLimiter;

    @Value("${auth.kakao.max-per-5-min:30}")
    private int maxKakaoAttemptsPerFiveMinutes = 30;

    public AuthController(AuthService authService,
                          SessionTokenService sessionTokenService,
                          SimpleRateLimiter rateLimiter) {
        this.authService = authService;
        this.sessionTokenService = sessionTokenService;
        this.rateLimiter = rateLimiter;
    }

    /**
     * 카카오 로그인: Firebase 커스텀 토큰 + API 인증용 세션 토큰 발급
     */
    @PostMapping("/kakao")
    public ResponseEntity<?> authenticateKakao(@RequestBody(required = false) KakaoAuthRequest request,
                                                HttpServletRequest httpRequest) {
        String accessToken = request == null ? null : request.getKakaoAccessToken();
        if (accessToken == null || accessToken.isBlank() || accessToken.length() > 4096) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "카카오 로그인 정보를 확인해주세요."));
        }
        String address = httpRequest.getRemoteAddr() == null
                ? "unknown" : httpRequest.getRemoteAddr();
        if (!rateLimiter.tryAcquire(
                "kakao-auth:" + address, maxKakaoAttemptsPerFiveMinutes, 5 * 60_000L)) {
            return ResponseEntity.status(429).body(Map.of(
                    "success", false,
                    "message", "로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요."));
        }
        try {
            AuthService.KakaoAuthResult result = authService.authenticateKakao(accessToken.trim());
            String sessionToken = sessionTokenService.createToken(result.firebaseUid());
            return ResponseEntity.ok(new FirebaseTokenResponse(
                    result.firebaseCustomToken(),
                    result.firebaseUid(),
                    sessionToken
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "카카오 로그인 정보를 확인해주세요."));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of(
                            "success", false,
                            "message", "인증에 실패했습니다. 카카오 로그인을 다시 시도해주세요."));
        }
    }
}
