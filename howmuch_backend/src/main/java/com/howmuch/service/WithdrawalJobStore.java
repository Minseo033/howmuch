package com.howmuch.service;

import com.google.cloud.firestore.*;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.HashMap;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

/** Durable deletion queue, independent of the user documents being deleted. */
@Service
public class WithdrawalJobStore {
    private final Firestore db;
    private static final long STORE_TIMEOUT_SECONDS = 10;
    // Let other instances' 30-second authentication caches expire before deletion.
    static final long AUTH_DRAIN_MILLIS = 35_000;
    static final long LEASE_MILLIS = 15 * 60_000;

    public record Job(String uid, String requestId, String state, int attempts,
                      long nextAttemptAt, long leaseUntil, String leaseOwner) {
        public boolean completed() { return "COMPLETED".equals(state); }
        public Map<String, Object> response() {
            return Map.of("success", true, "requestId", requestId, "state", state);
        }
    }

    public WithdrawalJobStore(Firestore db) { this.db = db; }

    public Job submit(String uid, String requestId, long now) throws Exception {
        validateRequestId(requestId);
        return db.runTransaction(tx -> {
            DocumentReference jobRef = jobReference(uid);
            DocumentReference sessionRef = sessionReference(uid);
            DocumentSnapshot previous = tx.get(jobRef).get();
            DocumentSnapshot session = tx.get(sessionRef).get();
            if (previous.exists()) {
                Job old = job(previous);
                if (old.requestId().equals(requestId)) return old;
                if (!old.completed()) throw new IllegalStateException("이미 탈퇴 처리 중입니다.");
            }
            Job next = new Job(uid, requestId, "PENDING", 0, now + AUTH_DRAIN_MILLIS, 0, "");
            tx.set(jobRef, fields(next));
            Long cutoff = session.getLong("revokedAfter");
            tx.set(sessionRef, Map.of("revokedAfter", Math.max(cutoff == null ? Long.MIN_VALUE : cutoff, now),
                    "withdrawalPending", true, "updatedAt", now), SetOptions.merge());
            return next;
        }).get(STORE_TIMEOUT_SECONDS, TimeUnit.SECONDS);
    }

    /**
     * 관리자의 강제 탈퇴 요청 시 세션을 즉시 차단(withdrawalPending=true)하고 35초 인증 캐시 만료 대기
     * (AUTH_DRAIN_MILLIS)를 지키는 PENDING 작업을 큐에 넣습니다. 이미 진행 중인 작업이 있으면 기존 임대(lease)와
     * 대기 시각을 덮어쓰지 않고 그대로 유지합니다.
     */
    public Job submitForAdmin(String uid, String requestId, long now) throws Exception {
        validateRequestId(requestId);
        return db.runTransaction(tx -> {
            DocumentReference jobRef = jobReference(uid);
            DocumentReference sessionRef = sessionReference(uid);
            DocumentSnapshot previous = tx.get(jobRef).get();
            DocumentSnapshot session = tx.get(sessionRef).get();
            Long cutoff = session == null ? null : session.getLong("revokedAfter");
            tx.set(sessionRef, Map.of(
                    "revokedAfter", Math.max(cutoff == null ? Long.MIN_VALUE : cutoff, now),
                    "withdrawalPending", true,
                    "updatedAt", now), SetOptions.merge());
            if (previous != null && previous.exists()) {
                Job old = job(previous);
                if (!old.completed()) {
                    return old;
                }
            }
            Job next = new Job(uid, requestId, "PENDING", 0, now + AUTH_DRAIN_MILLIS, 0, "");
            tx.set(jobRef, fields(next));
            return next;
        }).get(STORE_TIMEOUT_SECONDS, TimeUnit.SECONDS);
    }

    /** The random request ID is a receipt for status only; no uid or user data is returned. */
    public Job status(String requestId) throws Exception {
        validateRequestId(requestId);
        var docs = db.collection("withdrawal_jobs").whereEqualTo("requestId", requestId)
                .limit(1).get().get(STORE_TIMEOUT_SECONDS, TimeUnit.SECONDS).getDocuments();
        return docs.isEmpty() ? null : job(docs.getFirst());
    }

    public java.util.List<Job> pending() throws Exception {
        return db.collection("withdrawal_jobs").whereEqualTo("state", "PENDING")
                .get().get(STORE_TIMEOUT_SECONDS, TimeUnit.SECONDS).getDocuments().stream()
                .map(WithdrawalJobStore::job).toList();
    }

    public Job claim(Job candidate, long now) throws Exception {
        return db.runTransaction(tx -> {
            DocumentReference ref = jobReference(candidate.uid());
            DocumentSnapshot snapshot = tx.get(ref).get();
            if (!snapshot.exists()) return null;
            Job current = job(snapshot);
            if (current.completed() || !current.requestId().equals(candidate.requestId())
                    || current.nextAttemptAt() > now || current.leaseUntil() > now) return null;
            Job claimed = new Job(current.uid(), current.requestId(), "PENDING", current.attempts() + 1,
                    current.nextAttemptAt(), now + LEASE_MILLIS, UUID.randomUUID().toString());
            tx.set(ref, fields(claimed));
            return claimed;
        }).get(STORE_TIMEOUT_SECONDS, TimeUnit.SECONDS);
    }

    public void finish(Job claimed, boolean success, long now) throws Exception {
        db.runTransaction(tx -> {
            DocumentReference ref = jobReference(claimed.uid());
            Job current = job(tx.get(ref).get());
            if (!current.requestId().equals(claimed.requestId())
                    || !current.leaseOwner().equals(claimed.leaseOwner())) return false;
            long retryDelay = Math.min(60 * 60_000L, 30_000L << Math.min(7, claimed.attempts() - 1));
            Job next = new Job(claimed.uid(), claimed.requestId(), success ? "COMPLETED" : "PENDING",
                    claimed.attempts(), success ? 0 : now + retryDelay, 0, "");
            Map<String, Object> saved = fields(next);
            // A completed receipt needs no raw account identity.
            if (success) saved.put("uid", "");
            tx.set(ref, saved);
            if (success) tx.set(sessionReference(claimed.uid()),
                    Map.of("withdrawalPending", false, "updatedAt", now), SetOptions.merge());
            return true;
        }).get(STORE_TIMEOUT_SECONDS, TimeUnit.SECONDS);
    }

    /** Keep a large account's active deletion from being claimed by another instance. */
    public void renew(Job claimed, long now) throws Exception {
        db.runTransaction(tx -> {
            DocumentReference ref = jobReference(claimed.uid());
            Job current = job(tx.get(ref).get());
            if (!current.completed() && current.requestId().equals(claimed.requestId())
                    && current.leaseOwner().equals(claimed.leaseOwner())) {
                tx.set(ref, Map.of("leaseUntil", now + LEASE_MILLIS), SetOptions.merge());
            }
            return true;
        }).get(STORE_TIMEOUT_SECONDS, TimeUnit.SECONDS);
    }

    static void validateRequestId(String id) {
        if (id == null || !id.matches("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}"))
            throw new IllegalArgumentException("탈퇴 요청 식별자를 확인해주세요.");
    }

    private DocumentReference jobReference(String uid) {
        return db.collection("withdrawal_jobs").document(SessionRevocationStore.documentId(uid));
    }
    private DocumentReference sessionReference(String uid) {
        return db.collection("session_revocations").document(SessionRevocationStore.documentId(uid));
    }
    private static Job job(DocumentSnapshot doc) {
        return new Job(doc.getString("uid"), doc.getString("requestId"), doc.getString("state"),
                (int) number(doc, "attempts"), number(doc, "nextAttemptAt"), number(doc, "leaseUntil"),
                doc.getString("leaseOwner") == null ? "" : doc.getString("leaseOwner"));
    }
    private static long number(DocumentSnapshot doc, String field) {
        Long value = doc.getLong(field);
        return value == null ? 0 : value;
    }
    private static Map<String, Object> fields(Job job) {
        return new HashMap<>(Map.of("uid", job.uid(), "requestId", job.requestId(), "state", job.state(),
                "attempts", job.attempts(), "nextAttemptAt", job.nextAttemptAt(),
                "leaseUntil", job.leaseUntil(), "leaseOwner", job.leaseOwner()));
    }
}
