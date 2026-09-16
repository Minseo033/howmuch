package com.howmuch.service;

import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * 탈퇴 계정의 세션 발급 시각 기준을 Firestore에 보관합니다.
 *
 * <p>프로세스 메모리가 아닌 공용 저장소를 사용해야 재시작 뒤와 여러 Render 인스턴스에서도
 * 기존 토큰을 동일하게 거부할 수 있습니다. 문서 ID에는 원래 uid를 노출하거나 '/' 문자를
 * 사용할 수 없으므로 SHA-256 해시를 사용합니다.</p>
 */
@Service
@Slf4j
public class SessionRevocationStore {

    private static final String COLLECTION = "session_revocations";

    private final Firestore db;
    private final long timeoutMillis;

    public SessionRevocationStore(
            Firestore db,
            @Value("${session.revocation.store-timeout-ms:1500}") long timeoutMillis) {
        this.db = db;
        this.timeoutMillis = Math.max(100, timeoutMillis);
    }

    /** Returns the newest persistent revocation cutoff, or {@link Long#MIN_VALUE} when none exists. */
    public long getRevokedAfter(String uid) {
        try {
            DocumentSnapshot snapshot = reference(uid).get()
                    .get(timeoutMillis, TimeUnit.MILLISECONDS);
            Object value = snapshot.get("revokedAfter");
            return value instanceof Number number ? number.longValue() : Long.MIN_VALUE;
        } catch (Exception e) {
            throw new UnavailableException("세션 폐기 기준을 확인할 수 없습니다.", e);
        }
    }

    /**
     * Persists the highest cutoff. A transaction prevents simultaneous self/admin deletion
     * requests from accidentally moving the cutoff backwards.
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
