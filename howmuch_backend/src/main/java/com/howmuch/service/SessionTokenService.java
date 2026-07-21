package com.howmuch.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;

/**
 * 자체 세션 토큰 서비스.
 * 카카오 로그인 성공 시 발급하고, 이후 API 요청의 Authorization: Bearer 헤더를 검증하는 데 사용합니다.
 * 형식: base64url(uid:만료시각) + "." + base64url(HMAC-SHA256 서명)
 */
@Service
public class SessionTokenService {

    private final String secret;
    private final long ttlMillis;

    public SessionTokenService(
            @Value("${session.secret:dev-only-howmuch-session-secret-change-me}") String secret,
            @Value("${session.ttl-hours:168}") long ttlHours) {
        this.secret = secret;
        this.ttlMillis = ttlHours * 60L * 60L * 1000L;
    }

    /** uid를 담은 서명된 세션 토큰을 발급합니다. */
    public String createToken(String uid) {
        long expiry = System.currentTimeMillis() + ttlMillis;
        String payload = uid + ":" + expiry;
        String encodedPayload = Base64.getUrlEncoder().withoutPadding()
                .encodeToString(payload.getBytes(StandardCharsets.UTF_8));
        String signature = sign(payload);
        return encodedPayload + "." + signature;
    }

    /**
     * 토큰을 검증하고 uid를 반환합니다.
     * 서명 불일치, 형식 오류, 만료 시 null을 반환합니다.
     */
    public String verifyAndGetUid(String token) {
        try {
            if (token == null || token.isBlank()) return null;
            int dot = token.lastIndexOf('.');
            if (dot <= 0) return null;

            String encodedPayload = token.substring(0, dot);
            String signature = token.substring(dot + 1);

            String payload = new String(Base64.getUrlDecoder().decode(encodedPayload), StandardCharsets.UTF_8);
            String expected = sign(payload);
            // 타이밍 공격 방지를 위해 상수 시간 비교
            if (!MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8),
                    signature.getBytes(StandardCharsets.UTF_8))) {
                return null;
            }

            int sep = payload.lastIndexOf(':');
            if (sep <= 0) return null;
            long expiry = Long.parseLong(payload.substring(sep + 1));
            if (System.currentTimeMillis() > expiry) return null;

            return payload.substring(0, sep);
        } catch (Exception e) {
            return null;
        }
    }

    private String sign(String payload) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] raw = mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        } catch (Exception e) {
            throw new IllegalStateException("세션 토큰 서명 실패", e);
        }
    }
}