package com.howmuch.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.Map;
import java.time.Duration;

@Service
@Slf4j
public class AuthService {

    private final WebClient webClient;
    /**
     * 카카오 개발자 콘솔의 앱 ID(숫자). 설정하면 다른 카카오 앱에서 발급된 액세스 토큰으로
     * 우리 서비스에 로그인하는 토큰 치환을 막는다. 비어 있으면 기존처럼 확인을 건너뛴다.
     */
    private final String expectedKakaoAppId;

    public AuthService(WebClient.Builder webClientBuilder,
                       @Value("${kakao.app-id:}") String expectedKakaoAppId) {
        this.webClient = webClientBuilder.baseUrl("https://kapi.kakao.com").build();
        this.expectedKakaoAppId = expectedKakaoAppId == null ? "" : expectedKakaoAppId.trim();
        if (this.expectedKakaoAppId.isEmpty()) {
            log.warn("KAKAO_APP_ID가 없어 카카오 토큰의 앱 소속 확인을 건너뜁니다. 운영 환경에는 앱 ID를 설정하세요.");
        }
    }

    /**
     * 카카오 로그인 결과. firebaseCustomToken은 응답 형식 호환을 위해 남겨 둔 필드로 항상 null이다
     * (앱은 이 토큰을 쓰지 않으며, 로그인마다 발급하면 실패 지점만 늘어난다).
     */
    public record KakaoAuthResult(
            String firebaseUid,
            String firebaseCustomToken,
            String email,
            String profileImageUrl) {}

    /**
     * 카카오 액세스 토큰을 검증하고 uid를 만듭니다.
     */
    public KakaoAuthResult authenticateKakao(String kakaoAccessToken) throws Exception {
        if (kakaoAccessToken == null || kakaoAccessToken.isBlank()) {
            throw new IllegalArgumentException("카카오 액세스 토큰이 필요합니다.");
        }
        if (kakaoAccessToken.length() > 4096) {
            throw new IllegalArgumentException("카카오 액세스 토큰이 너무 깁니다.");
        }
        // 1. 토큰이 우리 앱에서 발급됐는지 확인 (설정된 경우)
        String tokenOwnerId = null;
        if (!expectedKakaoAppId.isEmpty()) {
            Map<String, Object> tokenInfo = fetchKakaoTokenInfo(kakaoAccessToken);
            if (!issuedForApp(tokenInfo, expectedKakaoAppId)) {
                // AuthController가 IllegalArgumentException 외의 예외를 401로 응답한다.
                throw new SecurityException("다른 카카오 앱에서 발급된 토큰입니다.");
            }
            tokenOwnerId = String.valueOf(tokenInfo.get("id"));
        }

        // 2. 카카오 사용자 정보 가져오기
        Map<String, Object> kakaoResponse = fetchKakaoUserInfo(kakaoAccessToken);

        if (kakaoResponse == null || !kakaoResponse.containsKey("id")) {
            throw new RuntimeException("카카오 인증에 실패했습니다.");
        }

        // 카카오 회원번호 (UID로 사용)
        String kakaoUserId = kakaoResponse.get("id").toString();
        if (tokenOwnerId != null && !tokenOwnerId.equals(kakaoUserId)) {
            throw new SecurityException("카카오 토큰과 사용자 정보가 일치하지 않습니다.");
        }
        String firebaseUid = "kakao:" + kakaoUserId;

        return new KakaoAuthResult(
                firebaseUid,
                null,
                kakaoEmail(kakaoResponse),
                kakaoProfileImageUrl(kakaoResponse));
    }

    /** access_token_info 응답의 app_id가 설정된 앱 ID와 같은지 확인한다. */
    static boolean issuedForApp(Map<String, Object> tokenInfo, String expectedAppId) {
        if (tokenInfo == null || expectedAppId == null || expectedAppId.isBlank()) return false;
        Object appId = tokenInfo.get("app_id");
        Object ownerId = tokenInfo.get("id");
        return appId != null && ownerId != null
                && expectedAppId.trim().equals(appId.toString().trim());
    }

    static String kakaoEmail(Map<String, Object> response) {
        return nestedString(response, "kakao_account", "email");
    }

    static String kakaoProfileImageUrl(Map<String, Object> response) {
        String image = nestedString(response, "kakao_account", "profile", "profile_image_url");
        return image.isBlank()
                ? nestedString(response, "kakao_account", "profile", "thumbnail_image_url")
                : image;
    }

    @SuppressWarnings("unchecked")
    private static String nestedString(Map<String, Object> source, String... path) {
        Object value = source;
        for (String key : path) {
            if (!(value instanceof Map<?, ?> map)) return "";
            value = map.get(key);
        }
        return value instanceof String text ? text.trim() : "";
    }

    private Map<String, Object> fetchKakaoUserInfo(String accessToken) {
        return webClient.get()
                .uri("/v2/user/me")
                .header("Authorization", "Bearer " + accessToken)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {})
                .block(Duration.ofSeconds(10));
    }

    private Map<String, Object> fetchKakaoTokenInfo(String accessToken) {
        return webClient.get()
                .uri("/v1/user/access_token_info")
                .header("Authorization", "Bearer " + accessToken)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {})
                .block(Duration.ofSeconds(5));
    }
}
