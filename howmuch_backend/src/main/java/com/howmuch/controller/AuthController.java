package com.howmuch.controller;

import com.howmuch.dto.FirebaseTokenResponse;
import com.howmuch.dto.KakaoAuthRequest;
import com.howmuch.service.AuthService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    /**
     * 카카오 로그인을 통한 Firebase 커스텀 토큰 발행 엔드포인트
     */
    @PostMapping("/kakao")
    public ResponseEntity<?> authenticateKakao(@RequestBody KakaoAuthRequest request) {
        try {
            String customToken = authService.createFirebaseToken(request.getKakaoAccessToken());
            return ResponseEntity.ok(new FirebaseTokenResponse(customToken));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body("인증 실패: " + e.getMessage());
        }
    }
}
