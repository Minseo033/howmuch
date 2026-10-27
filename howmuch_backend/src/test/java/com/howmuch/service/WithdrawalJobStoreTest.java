package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.*;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

/** Execute production transaction callbacks against a small atomic in-memory store. */
class WithdrawalJobStoreTest {
    private static final String ID = "00000000-0000-4000-8000-000000000001";
    private final Firestore db = mock(Firestore.class);
    private final Map<DocumentReference, Map<String, Object>> docs = new HashMap<>();
    private final Map<String, CollectionReference> collections = new HashMap<>();
    private final Map<String, DocumentReference> refs = new HashMap<>();

    @SuppressWarnings("unchecked")
    WithdrawalJobStoreTest() throws Exception {
        when(db.collection(anyString())).thenAnswer(call -> collections.computeIfAbsent(call.getArgument(0), name -> {
            var collection = mock(CollectionReference.class);
            when(collection.document(anyString())).thenAnswer(c -> refs.computeIfAbsent(name + "/" + c.getArgument(0), k -> mock(DocumentReference.class)));
            return collection;
        }));
        when(db.runTransaction(any())).thenAnswer(call -> {
            var tx = mock(Transaction.class);
            var writes = new HashMap<DocumentReference, Map<String, Object>>();
            when(tx.get(any(DocumentReference.class))).thenAnswer(read -> {
                Map<String, Object> values = docs.get(read.getArgument(0));
                var snapshot = mock(DocumentSnapshot.class);
                when(snapshot.exists()).thenReturn(values != null);
                when(snapshot.getString(anyString())).thenAnswer(c -> values == null ? null : values.get(c.getArgument(0)));
                when(snapshot.getLong(anyString())).thenAnswer(c -> values == null || !(values.get(c.getArgument(0)) instanceof Number n) ? null : n.longValue());
                return ApiFutures.immediateFuture(snapshot);
            });
            when(tx.set(any(), any(Map.class))).thenAnswer(c -> { writes.put(c.getArgument(0), new HashMap<>(c.getArgument(1))); return tx; });
            when(tx.set(any(), any(Map.class), any(SetOptions.class))).thenAnswer(c -> {
                DocumentReference ref = c.getArgument(0);
                var merged = new HashMap<>(docs.getOrDefault(ref, Map.of()));
                merged.putAll(c.getArgument(1)); writes.put(ref, merged); return tx;
            });
            try {
                Object result = ((Transaction.Function<Object>) call.getArgument(0)).updateCallback(tx);
                docs.putAll(writes);
                return ApiFutures.immediateFuture(result);
            } catch (Exception e) { return ApiFutures.immediateFailedFuture(e); }
        });
    }

    @Test
    void submissionAtomicallyQueuesDeletionBlocksLoginAndIsIdempotent() throws Exception {
        var store = new WithdrawalJobStore(db);
        var job = store.submit("user", ID, 100);
        assertThat(job.state()).isEqualTo("PENDING");
        assertThat(job.nextAttemptAt()).isEqualTo(100 + WithdrawalJobStore.AUTH_DRAIN_MILLIS);
        assertThat(store.submit("user", ID, 999)).isEqualTo(job);
        assertThat(session()).containsEntry("withdrawalPending", true).containsEntry("revokedAfter", 100L);
        assertThatThrownBy(() -> store.submit("user", "00000000-0000-4000-8000-000000000002", 999))
                .hasCauseInstanceOf(IllegalStateException.class);
    }

    @Test
    void restartCannotTakeActiveLeaseButRecoversExpiredLeaseAndRetriesFailures() throws Exception {
        var store = new WithdrawalJobStore(db);
        var job = store.submit("user", ID, 100);
        assertThat(store.claim(job, 101)).isNull();
        long due = job.nextAttemptAt();
        var claimed = store.claim(job, due);
        var restarted = new WithdrawalJobStore(db);
        assertThat(restarted.claim(job, due + 1)).isNull();
        var recovered = restarted.claim(job, claimed.leaseUntil());
        assertThat(recovered.attempts()).isEqualTo(2);
        restarted.finish(claimed, true, due + 2); // stale worker cannot complete another worker's job
        assertThat(session()).containsEntry("withdrawalPending", true);
        restarted.finish(recovered, false, recovered.leaseUntil());
        assertThat(session()).containsEntry("withdrawalPending", true);
        assertThat(restarted.claim(job, recovered.leaseUntil())).isNull();
        var retry = restarted.claim(job, recovered.leaseUntil() + 60_000);
        assertThat(retry).isNotNull();
        restarted.finish(retry, true, retry.leaseUntil());
        assertThat(session()).containsEntry("withdrawalPending", false);
        assertThat(store.submit("user", ID, Long.MAX_VALUE).completed()).isTrue();
    }

    @Test
    void adminSubmissionKeepsAuthDrainAndNeverOverwritesAnActiveLease() throws Exception {
        var store = new WithdrawalJobStore(db);
        var job = store.submitForAdmin("user", ID, 200);
        assertThat(job.state()).isEqualTo("PENDING");
        assertThat(job.nextAttemptAt()).isEqualTo(200 + WithdrawalJobStore.AUTH_DRAIN_MILLIS);
        assertThat(job.leaseOwner()).isEmpty();
        assertThat(session()).containsEntry("withdrawalPending", true).containsEntry("revokedAfter", 200L);

        long due = job.nextAttemptAt();
        var claimed = store.claim(job, due);
        assertThat(claimed).isNotNull();
        var secondAdminCall = store.submitForAdmin("user", "00000000-0000-4000-8000-000000000009", due + 10);
        assertThat(secondAdminCall.leaseOwner()).isEqualTo(claimed.leaseOwner());
        assertThat(secondAdminCall.requestId()).isEqualTo(claimed.requestId());
    }

    @Test
    void statusReceiptContainsNoUserIdentityAndRejectsGuessableIds() {
        var job = new WithdrawalJobStore.Job("private-uid", ID, "PENDING", 0, 0, 0, "");
        assertThat(job.response()).doesNotContainKey("uid").containsEntry("requestId", ID);
        assertThatThrownBy(() -> WithdrawalJobStore.validateRequestId("user"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    private Map<String, Object> session() {
        return docs.get(refs.get("session_revocations/" + SessionRevocationStore.documentId("user")));
    }
}
