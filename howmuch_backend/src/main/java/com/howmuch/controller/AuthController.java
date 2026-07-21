package com.howmuch.controller;

import com.howmuch.dto.FirebaseTokenResponse;
import com.howmuch.dto.KakaoAuthRequest;
import com.howmuch.service.AuthService;
import com.howmuch.service.SessionTokenService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;
    private final SessionTokenService sessionTokenService;

    public AuthController(AuthService authService, SessionTokenService sessionTokenService) {
        this.authService = authService;
        this.sessionTokenService = sessionTokenService;
    }

    /**
     * 카카오 로그인: Firebase 커스텀 토큰 + API 인증용 세션 토큰 발급
     */
    @PostMapping("/kakao")
    public ResponseEntity<?> authenticateKakao(@RequestBody KakaoAuthRequest request) {
        try {
            AuthService.KakaoAuthResult result = authService.authenticateKakao(request.getKakaoAccessToken());
            String sessionToken = sessionTokenService.createToken(result.firebaseUid());
            return ResponseEntity.ok(new FirebaseTokenResponse(
                    result.firebaseCustomToken(),
                    result.firebaseUid(),
                    sessionToken
            ));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body("인증 실패: " + e.getMessage());
        }
    }
}