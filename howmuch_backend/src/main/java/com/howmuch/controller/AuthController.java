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
            // 💡 날부 에러 상세는 로그에만 — 클라이언트에는 일반 메시지 (구조 노출 방지)
            System.err.println("[AuthController] 카카오 인증 실패: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body("인증에 실패했습니다. 카카오 로그인을 다시 시도해주세요.");
        }
    }
}