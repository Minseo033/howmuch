package com.howmuch.service;

import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class AuthServiceIdentityTest {

    @Test
    void extractsIdentityFromVerifiedKakaoResponse() {
        Map<String, Object> response = Map.of(
                "kakao_account", Map.of(
                        "email", " kakao@example.com ",
                        "profile", Map.of(
                                "profile_image_url", "https://k.kakaocdn.net/profile.jpg")));

        assertEquals("kakao@example.com", AuthService.kakaoEmail(response));
        assertEquals(
                "https://k.kakaocdn.net/profile.jpg",
                AuthService.kakaoProfileImageUrl(response));
    }

    @Test
    void fallsBackToThumbnailWhenFullImageIsMissing() {
        Map<String, Object> response = Map.of(
                "kakao_account", Map.of(
                        "profile", Map.of(
                                "thumbnail_image_url", "https://k.kakaocdn.net/thumb.jpg")));

        assertEquals("", AuthService.kakaoEmail(response));
        assertEquals(
                "https://k.kakaocdn.net/thumb.jpg",
                AuthService.kakaoProfileImageUrl(response));
    }

    @Test
    void acceptsOnlyTokensIssuedForTheConfiguredKakaoApp() {
        // Kakao returns app_id and id as JSON numbers.
        Map<String, Object> ours = Map.of("id", 4242L, "expires_in", 7199, "app_id", 1234567);
        Map<String, Object> otherApp = Map.of("id", 4242L, "expires_in", 7199, "app_id", 7654321);

        org.junit.jupiter.api.Assertions.assertTrue(AuthService.issuedForApp(ours, "1234567"));
        org.junit.jupiter.api.Assertions.assertTrue(AuthService.issuedForApp(ours, " 1234567 "));
        org.junit.jupiter.api.Assertions.assertFalse(AuthService.issuedForApp(otherApp, "1234567"));
        org.junit.jupiter.api.Assertions.assertFalse(AuthService.issuedForApp(Map.of("id", 4242L), "1234567"));
        org.junit.jupiter.api.Assertions.assertFalse(AuthService.issuedForApp(null, "1234567"));
    }
}
