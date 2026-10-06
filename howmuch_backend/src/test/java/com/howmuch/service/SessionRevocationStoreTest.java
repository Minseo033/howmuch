package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Transaction;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class SessionRevocationStoreTest {

    @Test
    void usesStableOpaqueDocumentIdsForFirebaseStyleUids() {
        String kakaoUid = "kakao:123456789";

        String documentId = SessionRevocationStore.documentId(kakaoUid);

        assertThat(documentId).doesNotContain(kakaoUid).doesNotContain(":").doesNotContain("/");
        assertThat(documentId).isEqualTo(SessionRevocationStore.documentId(kakaoUid));
        assertThat(documentId).isNotEqualTo(SessionRevocationStore.documentId("kakao:123456780"));
    }

    @Test
    void readsTheAccountCutoffAndLoggedOutTokensFromOneDocument() {
        var revocation = SessionRevocationStore.revocationOf(Map.of(
                "revokedAfter", 100L,
                "revokedTokens", Map.of("500", Long.MAX_VALUE, "bad-key", Long.MAX_VALUE, "600", "not-a-number")));

        assertThat(revocation.rejects(100L)).isTrue();
        assertThat(revocation.rejects(500L)).isTrue();
        assertThat(revocation.rejects(600L)).isFalse();
        assertThat(revocation.rejects(700L)).isFalse();
        assertThat(SessionRevocationStore.revocationOf(null).rejects(1L)).isFalse();
    }

    @Test
    @SuppressWarnings("unchecked")
    void logoutKeepsTheAccountCutoffAndDropsExpiredEntries() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference collection = mock(CollectionReference.class);
        DocumentReference reference = mock(DocumentReference.class);
        Transaction transaction = mock(Transaction.class);
        DocumentSnapshot snapshot = mock(DocumentSnapshot.class);
        when(db.collection("session_revocations")).thenReturn(collection);
        when(collection.document(anyString())).thenReturn(reference);
        when(transaction.get(reference)).thenReturn(ApiFutures.immediateFuture(snapshot));
        long now = System.currentTimeMillis();
        when(snapshot.exists()).thenReturn(true);
        when(snapshot.getData()).thenReturn(Map.of("revokedAfter", 100L,
                "revokedTokens", Map.of("500", now + 3_600_000L, "300", now - 1L)));
        when(db.runTransaction(any())).thenAnswer(invocation -> {
            Transaction.Function<Object> function = invocation.getArgument(0);
            return ApiFutures.immediateFuture(function.updateCallback(transaction));
        });
        SessionRevocationStore store = new SessionRevocationStore(db, 1_000);

        var result = store.revokeToken("kakao:1", 700L, now + 7_200_000L);

        ArgumentCaptor<Map<String, Object>> written = ArgumentCaptor.forClass(Map.class);
        verify(transaction).set(eq(reference), written.capture());
        assertThat(written.getValue()).containsEntry("revokedAfter", 100L);
        assertThat((Map<String, Long>) written.getValue().get("revokedTokens")).containsOnlyKeys("500", "700");
        assertThat(result.rejects(700L)).isTrue();
        assertThat(result.rejects(500L)).isTrue();
        assertThat(result.rejects(50L)).isTrue();
        assertThat(result.rejects(800L)).isFalse();
    }
}
