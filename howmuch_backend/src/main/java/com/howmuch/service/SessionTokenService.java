package com.howmuch.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import lombok.extern.slf4j.Slf4j;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.LongSupplier;

/**
 * 자체 세션 토큰 서비스.
 * 카카오 로그인 성공 시 발급하고, 이후 API 요청의 Authorization: Bearer 헤더를 검증하는 데 사용합니다.
 * 형식: base64url(uid:발급시각:만료시각) + "." + base64url(HMAC-SHA256 서명)
 *
 * <p>세션 폐기 기준(탈퇴 시 계정 전체, 로그아웃 시 기기 하나)은 Firestore에 있지만, 요청마다 읽으면
 * 비용과 지연이 커지고 저장소 장애가 모든 인증 요청으로 번집니다. 그래서 uid별 기준을 짧게(30초)
 * 캐시합니다. 이 인스턴스에서 폐기하면 캐시도 즉시 갱신하므로, 다른 인스턴스에서만 최대 30초 늦게
 * 반영됩니다.</p>
 */
@Service
@Slf4j
public class SessionTokenService {

    private static final String DEV_FALLBACK_SECRET = "dev-only-howmuch-session-secret-change-me";
    static final long REVOCATION_CACHE_TTL_MILLIS = 30_000L;
    private static final int REVOCATION_CACHE_MAX_ENTRIES = 10_000;

    private final String secret;
    private final long ttlMillis;
    private final SessionRevocationStore sessionRevocationStore;
    private final LongSupplier clock;
    // Store-less construction is retained only for small, isolated unit tests.
    private final ConcurrentHashMap<String, Long> revokedAfterByUid = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Set<Long>> revokedTokensByUid = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, CachedRevocation> revocationCache = new ConcurrentHashMap<>();

    private record CachedRevocation(SessionRevocationStore.Revocation revocation, long expiresAtMillis) {}

    private record ParsedToken(String uid, long issuedAt, long expiry) {}

    @Autowired
    public SessionTokenService(
            @Value("${session.secret:}") String secret,
            @Value("${session.ttl-hours:168}") long ttlHours,
            @Value("${session.allow-dev-secret:true}") boolean allowDevSecret,
            SessionRevocationStore sessionRevocationStore) {
        this(secret, ttlHours, allowDevSecret, sessionRevocationStore, System::currentTimeMillis);
    }

    /** 테스트에서 시계를 바꿔 끼우기 위한 생성자. */
    SessionTokenService(String secret, long ttlHours, boolean allowDevSecret,
                        SessionRevocationStore sessionRevocationStore, LongSupplier clock) {
        // 💡 fail-fast: 알려진 dev 기본값/빈 시크릿으로는 토큰 위조가 가능하므로,
        //    운영(session.allow-dev-secret=false)에서는 부팅을 거부합니다.
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException(
                    "SESSION_SECRET이 설정되지 않았습니다. 환경변수 SESSION_SECRET을 반드시 주입하세요.");
        }
        if (DEV_FALLBACK_SECRET.equals(secret) && !allowDevSecret) {
            throw new IllegalStateException(
                    "SESSION_SECRET에 dev 기본값이 사용되었습니다. 운영 환경에서는 반드시 새 랜덤 시크릿으로 교체하세요.");
        }
        if (DEV_FALLBACK_SECRET.equals(secret)) {
            log.warn("개발용 SESSION_SECRET을 사용 중입니다. 운영에서는 별도 시크릿을 설정해야 합니다.");
        }
        this.secret = secret;
        this.ttlMillis = ttlHours * 60L * 60L * 1000L;
        this.sessionRevocationStore = sessionRevocationStore;
        this.clock = clock;
    }

    SessionTokenService(String secret, long ttlHours, boolean allowDevSecret) {
        this(secret, ttlHours, allowDevSecret, null);
    }

    /** uid를 담은 서명된 세션 토큰을 발급합니다. */
    public String createToken(String uid) {
        long now = clock.getAsLong();
        SessionRevocationStore.Revocation revocation = revocation(uid);
        long issuedAt = Math.max(now, revocation.revokedAfter() + 1);
        // A logged-out device's issue time must never be reused for a new session.
        while (revocation.revokedIssuedAt().contains(issuedAt)) issuedAt++;
        long expiry = issuedAt + ttlMillis;
        String payload = uid + ":" + issuedAt + ":" + expiry;
        String encodedPayload = Base64.getUrlEncoder().withoutPadding()
                .encodeToString(payload.getBytes(StandardCharsets.UTF_8));
        String signature = sign(payload);
        return encodedPayload + "." + signature;
    }

    /**
     * 토큰을 검증하고 uid를 반환합니다.
     * 서명 불일치, 형식 오류, 만료, 폐기 시 null을 반환합니다.
     */
    public String verifyAndGetUid(String token) {
        ParsedToken parsed = parse(token);
        if (parsed == null || clock.getAsLong() > parsed.expiry()) return null;
        try {
            return revocation(parsed.uid()).rejects(parsed.issuedAt()) ? null : parsed.uid();
        } catch (SessionRevocationStore.UnavailableException e) {
            // A valid signature with an unavailable revocation check is not an
            // expired token. Let the filter fail closed with a retryable 503.
            throw e;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * 로그아웃한 기기의 토큰 하나만 폐기합니다. 같은 계정의 다른 기기 세션은 유지됩니다.
     * 서명이 맞지 않거나 이미 만료된 토큰은 무시하고 false를 돌려줍니다.
     */
    public boolean revokeToken(String token) {
        ParsedToken parsed = parse(token);
        long now = clock.getAsLong();
        if (parsed == null || now > parsed.expiry()) return false;
        if (sessionRevocationStore == null) {
            revokedTokensByUid.computeIfAbsent(parsed.uid(), key -> ConcurrentHashMap.newKeySet())
                    .add(parsed.issuedAt());
            return true;
        }
        SessionRevocationStore.Revocation stored =
                sessionRevocationStore.revokeToken(parsed.uid(), parsed.issuedAt(), parsed.expiry());
        Set<Long> tokens = new HashSet<>(stored.revokedIssuedAt());
        tokens.add(parsed.issuedAt());
        // This instance must stop trusting the token now, not after the cache expires.
        remember(parsed.uid(), new SessionRevocationStore.Revocation(stored.revokedAfter(), tokens), now);
        return true;
    }

    /** Immediately invalidates every session issued for this account so a deleted account cannot keep using APIs. */
    public void invalidateAllForUid(String uid) {
        if (uid != null && !uid.isBlank()) {
            long cutoff = clock.getAsLong();
            if (sessionRevocationStore != null) {
                long stored = sessionRevocationStore.revokeAt(uid, cutoff);
                remember(uid, new SessionRevocationStore.Revocation(Math.max(stored, cutoff), Set.of()), cutoff);
            } else {
                revokedAfterByUid.merge(uid, cutoff, Math::max);
            }
        }
    }

    private ParsedToken parse(String token) {
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

            int expirySeparator = payload.lastIndexOf(':');
            int issuedAtSeparator = expirySeparator <= 0
                    ? -1 : payload.lastIndexOf(':', expirySeparator - 1);
            if (issuedAtSeparator <= 0 || expirySeparator <= issuedAtSeparator + 1) return null;
            String uid = payload.substring(0, issuedAtSeparator);
            long issuedAt = Long.parseLong(payload.substring(issuedAtSeparator + 1, expirySeparator));
            long expiry = Long.parseLong(payload.substring(expirySeparator + 1));
            return new ParsedToken(uid, issuedAt, expiry);
        } catch (Exception e) {
            return null;
        }
    }

    private SessionRevocationStore.Revocation revocation(String uid) {
        if (sessionRevocationStore == null) {
            return new SessionRevocationStore.Revocation(
                    revokedAfterByUid.getOrDefault(uid, Long.MIN_VALUE),
                    revokedTokensByUid.getOrDefault(uid, Set.of()));
        }
        long now = clock.getAsLong();
        CachedRevocation cached = revocationCache.get(uid);
        if (cached != null && cached.expiresAtMillis() > now) {
            return cached.revocation();
        }
        // Fail closed: while the shared revocation store is unavailable, no previously
        // valid token may be trusted. The exception propagates and nothing is cached,
        // so the next request checks the store again.
        SessionRevocationStore.Revocation fresh = sessionRevocationStore.getRevocation(uid);
        return remember(uid, fresh, now);
    }

    private SessionRevocationStore.Revocation remember(
            String uid, SessionRevocationStore.Revocation incoming, long now) {
        if (revocationCache.size() >= REVOCATION_CACHE_MAX_ENTRIES) {
            revocationCache.entrySet().removeIf(entry -> entry.getValue().expiresAtMillis() <= now);
            if (revocationCache.size() >= REVOCATION_CACHE_MAX_ENTRIES) revocationCache.clear();
        }
        CachedRevocation next = new CachedRevocation(incoming, now + REVOCATION_CACHE_TTL_MILLIS);
        // Revocations only accumulate: never let a slower read undo a newer local revocation.
        return revocationCache.merge(uid, next, (previous, latest) -> {
            long cutoff = Math.max(previous.revocation().revokedAfter(), latest.revocation().revokedAfter());
            Set<Long> tokens = new HashSet<>(previous.revocation().revokedIssuedAt());
            tokens.addAll(latest.revocation().revokedIssuedAt());
            tokens.removeIf(issuedAt -> issuedAt <= cutoff);
            return new CachedRevocation(
                    new SessionRevocationStore.Revocation(cutoff, tokens), latest.expiresAtMillis());
        }).revocation();
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
