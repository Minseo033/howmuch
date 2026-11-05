package com.howmuch.service;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.*;
import com.howmuch.dto.FeedResponseDto;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.*;
import java.util.concurrent.CancellationException;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class FirebaseServiceCancellationTest {
    @AfterEach
    void clearInterrupt() { Thread.interrupted(); }

    @Test
    void preexistingInterruptRejectsReceiptSubmissionBeforeAnyFirestoreAccess() {
        Firestore db = mock(Firestore.class);
        ReportImageStorage images = mock(ReportImageStorage.class);
        FirebaseService service = new FirebaseService(db, images);
        Thread.currentThread().interrupt();

        assertThatThrownBy(() -> service.saveReceiptVerification("user", "store", "Store", "Menu", 6000L,
                "a".repeat(64), List.of("uploaded-image"), null,
                new com.howmuch.dto.VisitLocationEvidence(10d, 5d)))
                .isInstanceOf(CancellationException.class).hasMessageContaining("before persistence");
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        verifyNoInteractions(db, images);
    }

    @Test
    @SuppressWarnings("unchecked")
    void interruptObservedAfterDuplicateVisitReadStillPreventsReceiptWrite() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference visits = mock(CollectionReference.class);
        CollectionReference receipts = mock(CollectionReference.class);
        DocumentReference visit = mock(DocumentReference.class);
        DocumentReference receipt = mock(DocumentReference.class);
        ApiFuture<DocumentSnapshot> future = mock(ApiFuture.class);
        when(db.collection("visits")).thenReturn(visits);
        when(db.collection("receipt_verifications")).thenReturn(receipts);
        when(visits.document(anyString())).thenReturn(visit);
        when(receipts.document(anyString())).thenReturn(receipt);
        when(visit.get()).thenReturn(future);
        when(future.get()).thenAnswer(call -> {
            Thread.currentThread().interrupt();
            return mock(DocumentSnapshot.class);
        });
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

        assertThatThrownBy(() -> service.saveReceiptVerification("user", "store", "Store", "Menu", 6000L,
                "a".repeat(64), List.of("uploaded-image"), null,
                new com.howmuch.dto.VisitLocationEvidence(10d, 5d)))
                .isInstanceOf(CancellationException.class);
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        verify(receipt, never()).create(anyMap());
        verify(db, never()).runTransaction(any());
    }

    @Test
    @SuppressWarnings("unchecked")
    void interruptedCatalogRefreshKeepsSnapshotAndDoesNotStartCorrectionsRead() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference stores = mock(CollectionReference.class);
        ApiFuture<QuerySnapshot> future = mock(ApiFuture.class);
        when(db.collection("stores_user")).thenReturn(stores);
        when(stores.get()).thenReturn(future);
        when(future.get()).thenThrow(new InterruptedException("cancelled"));
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));
        List<Map<String, Object>> snapshot = List.of(Map.of("id", "existing"));
        ReflectionTestUtils.setField(service, "cachedUserStores", snapshot);

        assertThatThrownBy(service::refreshUserStores).isInstanceOf(CancellationException.class);

        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        assertThat(ReflectionTestUtils.getField(service, "cachedUserStores")).isSameAs(snapshot);
        verify(db, times(1)).collection(anyString());
    }

    @Test
    @SuppressWarnings("unchecked")
    void interruptedFeedLookupIsNotReportedAsMissing() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference stores = mock(CollectionReference.class);
        DocumentReference document = mock(DocumentReference.class);
        ApiFuture<DocumentSnapshot> future = mock(ApiFuture.class);
        when(db.collection("stores_user")).thenReturn(stores);
        when(stores.document("post")).thenReturn(document);
        when(document.get()).thenReturn(future);
        when(future.get()).thenThrow(new InterruptedException("cancelled"));
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

        assertThatThrownBy(() -> service.feedExists("post")).isInstanceOf(CancellationException.class);
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
    }

    @Test
    @SuppressWarnings("unchecked")
    void interruptedCleanupDoesNotRecordFailureOrDeleteImages() throws Exception {
        Firestore db = mock(Firestore.class);
        ReportImageStorage images = mock(ReportImageStorage.class);
        DocumentReference receipt = mock(DocumentReference.class);
        ApiFuture<DocumentSnapshot> future = mock(ApiFuture.class);
        when(receipt.get()).thenReturn(future);
        when(future.get()).thenThrow(new InterruptedException("cancelled"));
        FirebaseService service = new FirebaseService(db, images);

        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(service,
                "recordReceiptCleanupFailure", receipt, List.of("image")))
                .isInstanceOf(CancellationException.class);
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        verify(receipt, never()).update(anyMap());
        verifyNoInteractions(images);
    }

    @Test
    @SuppressWarnings("unchecked")
    void scheduledCleanupDoesNotTreatCancellationAsMissingStorageConfiguration() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference receipts = mock(CollectionReference.class);
        Query pending = mock(Query.class);
        QuerySnapshot result = mock(QuerySnapshot.class);
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        DocumentReference reference = mock(DocumentReference.class);
        ApiFuture<WriteResult> write = mock(ApiFuture.class);
        when(db.collection("receipt_verifications")).thenReturn(receipts);
        when(receipts.whereEqualTo("imageCleanupStatus", "PENDING")).thenReturn(pending);
        when(pending.limit(anyInt())).thenReturn(pending);
        when(pending.get()).thenReturn(com.google.api.core.ApiFutures.immediateFuture(result));
        when(result.getDocuments()).thenReturn(List.of(document));
        when(document.getString("status")).thenReturn("APPROVED");
        when(document.getReference()).thenReturn(reference);
        when(reference.update(anyMap())).thenReturn(write);
        when(write.get()).thenThrow(new InterruptedException("cancelled"));
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

        assertThatThrownBy(service::retryProcessedReceiptImageCleanup).isInstanceOf(CancellationException.class);
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        assertThat(ReflectionTestUtils.getField(service, "legacyReceiptCleanupSwept")).isEqualTo(false);
        verify(receipts, never()).whereIn(anyString(), anyList());
    }

    @Test
    void counterCacheUpdateHasNoSuccessBooleanAndKeepsOtherPostsUnchanged() {
        FirebaseService service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
        FeedResponseDto other = FeedResponseDto.builder().id("other").likes(2).comments(3).build();
        ReflectionTestUtils.setField(service, "cachedFeeds", List.of(
                FeedResponseDto.builder().id("post").likes(1).comments(1).build(), other));
        ReflectionTestUtils.invokeMethod(service, "updateCachedFeedCounts", "post", 7, 8);
        @SuppressWarnings("unchecked")
        List<FeedResponseDto> result = (List<FeedResponseDto>) ReflectionTestUtils.getField(service, "cachedFeeds");
        assertThat(result.get(0).getLikes()).isEqualTo(7);
        assertThat(result.get(0).getComments()).isEqualTo(8);
        assertThat(result.get(1)).isSameAs(other);
        ReflectionTestUtils.setField(service, "cachedFeeds", null);
        ReflectionTestUtils.invokeMethod(service, "updateCachedFeedCounts", "post", 7, 8);
        assertThat(ReflectionTestUtils.getField(service, "cachedFeeds")).isNull();
    }

    @Test
    void nonSecurityRecommendationShuffleIsDeterministicAndDoesNotMutatePool() {
        FirebaseService service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
        List<Map<String, Object>> pool = List.of(Map.of("id", "a"), Map.of("id", "b"),
                Map.of("id", "c"), Map.of("id", "d"));
        List<Map<String, Object>> expected = new ArrayList<>(pool);
        Collections.shuffle(expected, new Random(42L));
        Object first = ReflectionTestUtils.invokeMethod(service, "nearestShuffled",
                pool, null, null, 4, 42L, 3000d, new IdentityHashMap<>());
        Object second = ReflectionTestUtils.invokeMethod(service, "nearestShuffled",
                pool, null, null, 4, 42L, 3000d, new IdentityHashMap<>());
        assertThat(first).isEqualTo(expected).isEqualTo(second);
        assertThat(pool.get(0)).containsEntry("id", "a");
    }
}
