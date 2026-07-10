package com.howmuch.service;

import com.google.firebase.auth.FirebaseAuth;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.Map;

@Service
public class AuthService {

    private final FirebaseAuth firebaseAuth;
    private final WebClient webClient;

    public AuthService(ObjectProvider<FirebaseAuth> firebaseAuthProvider, WebClient.Builder webClientBuilder) {
        this.firebaseAuth = firebaseAuthProvider.getIfAvailable();
        this.webClient = webClientBuilder.baseUrl("https://kapi.kakao.com").build();
    }

    /**
     * 카카오 액세스 토큰을 사용하여 Firebase 커스텀 토큰을 생성합니다.
     */
    public String createFirebaseToken(String kakaoAccessToken) throws Exception {
        if (firebaseAuth == null) {
            return "dev-firebase-token";
        }

        // 1. 카카오 사용자 정보 가져오기
        Map<String, Object> kakaoResponse = fetchKakaoUserInfo(kakaoAccessToken);

        if (kakaoResponse == null || !kakaoResponse.containsKey("id")) {
            throw new RuntimeException("카카오 인증에 실패했습니다.");
        }

        // 카카오 회원번호 (UID로 사용)
        String kakaoUserId = kakaoResponse.get("id").toString();
        String firebaseUid = "kakao:" + kakaoUserId;

        // 2. Firebase 커스텀 토큰 발행
        return firebaseAuth.createCustomToken(firebaseUid);
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
