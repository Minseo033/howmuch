package com.howmuch.service;

import com.google.firebase.auth.FirebaseAuth;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.Map;

@Service
public class AuthService {

    private final FirebaseAuth firebaseAuth;
    private final WebClient webClient;

    public AuthService(FirebaseAuth firebaseAuth, WebClient.Builder webClientBuilder) {
        this.firebaseAuth = firebaseAuth;
        this.webClient = webClientBuilder.baseUrl("https://kapi.kakao.com").build();
    }

    /**
     * 카카오 로그인 결과 (uid + Firebase 커스텀 토큰)
     */
    public record KakaoAuthResult(String firebaseUid, String firebaseCustomToken) {}

    /**
     * 카카오 액세스 토큰을 검증하고 uid와 Firebase 커스텀 토큰을 생성합니다.
     */
    public KakaoAuthResult authenticateKakao(String kakaoAccessToken) throws Exception {
        // 1. 카카오 사용자 정보 가져오기
        Map<String, Object> kakaoResponse = fetchKakaoUserInfo(kakaoAccessToken);

        if (kakaoResponse == null || !kakaoResponse.containsKey("id")) {
            throw new RuntimeException("카카오 인증에 실패했습니다.");
        }

        // 카카오 회원번호 (UID로 사용)
        String kakaoUserId = kakaoResponse.get("id").toString();
        String firebaseUid = "kakao:" + kakaoUserId;

        // 2. Firebase 커스텀 토큰 발행
        String customToken = firebaseAuth.createCustomToken(firebaseUid);
        return new KakaoAuthResult(firebaseUid, customToken);
    }

    private Map<String, Object> fetchKakaoUserInfo(String accessToken) {
        return webClient.get()
                .uri("/v2/user/me")
                .header("Authorization", "Bearer " + accessToken)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {})
                .block();
    }
}
