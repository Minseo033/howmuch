package com.howmuch.service;

import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

/**
 * 세션 폐기 기준을 Firestore에 보관합니다.
 * <ul>
 *   <li>revokedAfter: 탈퇴 등으로 계정의 모든 세션을 끊은 시각. 이 시각 이전에 발급된 토큰은 모두 거부합니다.</li>
 *   <li>revokedTokens: 로그아웃한 기기의 토큰 발급 시각 → 만료 시각. 그 토큰 하나만 거부합니다.</li>
 * </ul>
 *
 * <p>프로세스 메모리가 아닌 공용 저장소를 사용해야 재시작 뒤와 여러 Render 인스턴스에서도
 * 기존 토큰을 동일하게 거부할 수 있습니다. 문서 ID에는 원래 uid를 노출하거나 '/' 문자를
 * 사용할 수 없으므로 SHA-256 해시를 사용합니다. 한 계정의 두 기준이 같은 문서에 있어
 * 토큰 검증은 계정당 한 번만 읽습니다.</p>
 */
@Service
public class SessionRevocationStore {

    private static final String COLLECTION = "session_revocations";
    /** 한 계정에 보관할 로그아웃 토큰 수 상한. 오래 만료된 항목부터 버립니다. */
    static final int MAX_REVOKED_TOKENS = 50;

    private final Firestore db;
    private final long timeoutMillis;

    /** 한 계정의 폐기 기준. */
    public record Revocation(long revokedAfter, Set<Long> revokedIssuedAt) {
        public static final Revocation NONE = new Revocation(Long.MIN_VALUE, Set.of());

        public Revocation {
            revokedIssuedAt = Set.copyOf(revokedIssuedAt);
        }

        /** 이 발급 시각의 토큰을 더는 믿으면 안 되는지 판단합니다. */
        public boolean rejects(long issuedAt) {
            return issuedAt <= revokedAfter || revokedIssuedAt.contains(issuedAt);
        }
    }

    public SessionRevocationStore(
            Firestore db,
            @Value("${session.revocation.store-timeout-ms:1500}") long timeoutMillis) {
        this.db = db;
        this.timeoutMillis = Math.max(100, timeoutMillis);
    }

    /** 계정 전체 기준과 로그아웃한 토큰 목록을 한 번에 읽습니다. */
    public Revocation getRevocation(String uid) {
        try {
            DocumentSnapshot snapshot = reference(uid).get()
                    .get(timeoutMillis, TimeUnit.MILLISECONDS);
            return revocationOf(snapshot.exists() ? snapshot.getData() : null);
        } catch (Exception e) {
            throw new UnavailableException("세션 폐기 기준을 확인할 수 없습니다.", e);
        }
    }

    /**
     * Persists the highest cutoff. A transaction prevents simultaneous self/admin deletion
     * requests from accidentally moving the cutoff backwards.
     * The cutoff covers every earlier logout entry, so those entries are dropped.
     */
    public long revokeAt(String uid, long requestedCutoff) {
        try {
            return db.runTransaction(transaction -> {
                DocumentReference reference = reference(uid);
                DocumentSnapshot snapshot = transaction.get(reference).get();
                Object value = snapshot.get("revokedAfter");
                long current = value instanceof Number number ? number.longValue() : Long.MIN_VALUE;
                long cutoff = Math.max(current, requestedCutoff);
                transaction.set(reference, Map.of(
                        "revokedAfter", cutoff,
                        "updatedAt", System.currentTimeMillis()));
                return cutoff;
            }).get(timeoutMillis, TimeUnit.MILLISECONDS);
        } catch (Exception e) {
            throw new UnavailableException("세션 폐기 기준을 저장할 수 없습니다.", e);
        }
    }

    /**
     * 로그아웃한 기기의 토큰 하나를 폐기합니다. 다른 기기의 세션은 유지됩니다.
     * 만료된 항목은 저장할 때마다 정리합니다.
     */
    public Revocation revokeToken(String uid, long issuedAt, long expiresAt) {
        try {
            return db.runTransaction(transaction -> {
                DocumentReference reference = reference(uid);
                DocumentSnapshot snapshot = transaction.get(reference).get();
                long now = System.currentTimeMillis();
                Map<String, Object> current = snapshot.exists() ? snapshot.getData() : null;
                long cutoff = revocationOf(current).revokedAfter();
                Map<String, Long> tokens = activeTokens(current, now);
                if (issuedAt > cutoff && expiresAt > now) {
                    tokens.put(Long.toString(issuedAt), expiresAt);
                }
                if (tokens.size() > MAX_REVOKED_TOKENS) {
                    tokens = tokens.entrySet().stream()
                            .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                            .limit(MAX_REVOKED_TOKENS)
                            .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue));
                }
                Map<String, Object> next = new HashMap<>();
                if (cutoff != Long.MIN_VALUE) next.put("revokedAfter", cutoff);
                next.put("revokedTokens", tokens);
                next.put("updatedAt", now);
                transaction.set(reference, next);
                return new Revocation(cutoff, issuedAtValues(tokens));
            }).get(timeoutMillis, TimeUnit.MILLISECONDS);
        } catch (Exception e) {
            throw new UnavailableException("세션 폐기 기준을 저장할 수 없습니다.", e);
        }
    }

    static Revocation revocationOf(Map<String, Object> data) {
        if (data == null) return Revocation.NONE;
        Object value = data.get("revokedAfter");
        long cutoff = value instanceof Number number ? number.longValue() : Long.MIN_VALUE;
        // Expired logout entries cannot authenticate anyway, so they are harmless if still listed.
        return new Revocation(cutoff, issuedAtValues(activeTokens(data, Long.MIN_VALUE)));
    }

    private static Map<String, Long> activeTokens(Map<String, Object> data, long now) {
        Map<String, Long> tokens = new HashMap<>();
        if (data == null || !(data.get("revokedTokens") instanceof Map<?, ?> raw)) return tokens;
        for (var entry : raw.entrySet()) {
            if (!(entry.getValue() instanceof Number expiry) || expiry.longValue() <= now) continue;
            try {
                Long.parseLong(String.valueOf(entry.getKey()));
                tokens.put(String.valueOf(entry.getKey()), expiry.longValue());
            } catch (NumberFormatException ignored) {
                // Skip malformed keys rather than failing every request for this account.
            }
        }
        return tokens;
    }

    private static Set<Long> issuedAtValues(Map<String, Long> tokens) {
        return tokens.keySet().stream().map(Long::parseLong).collect(Collectors.toSet());
    }

    private DocumentReference reference(String uid) {
        if (uid == null || uid.isBlank()) {
            throw new IllegalArgumentException("uid가 필요합니다.");
        }
        return db.collection(COLLECTION).document(documentId(uid));
    }

    static String documentId(String uid) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(uid.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(digest);
        } catch (Exception e) {
            throw new IllegalStateException("세션 폐기 문서 ID를 만들 수 없습니다.", e);
        }
    }

    public static class UnavailableException extends RuntimeException {
        UnavailableException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
