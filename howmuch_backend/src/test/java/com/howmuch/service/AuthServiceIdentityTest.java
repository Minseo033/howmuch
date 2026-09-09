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
}
