package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.google.cloud.firestore.Transaction;
import com.google.cloud.firestore.WriteResult;
import com.howmuch.dto.VisitRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** 계약 C9·FE-STORE-15·BE-CORE-4: 영수증 방문은 위치 방문과 같은 하루 1회 ID로 만들고, 방문일은 승인 시각이 아닙니다. */
class FirebaseServiceReceiptDuplicateVisitTest {
    private final Firestore db = mock(Firestore.class);
    private final Transaction transaction = mock(Transaction.class);
    private final CollectionReference receipts = mock(CollectionReference.class);
    private final CollectionReference visits = mock(CollectionReference.class);
    private final DocumentReference receiptRef = mock(DocumentReference.class);
    private final DocumentReference visitRef = mock(DocumentReference.class);
    private final DocumentSnapshot receipt = mock(DocumentSnapshot.class);
    private final DocumentSnapshot visit = mock(DocumentSnapshot.class);
    private final FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() throws Exception {
        when(db.collection("receipt_verifications")).thenReturn(receipts);
        when(db.collection("visits")).thenReturn(visits);
        when(receipts.document("receipt-1")).thenReturn(receiptRef);
        when(visits.document(anyString())).thenReturn(visitRef);
        when(visitRef.getId()).thenAnswer(invocation -> "visit-id");
        when(transaction.get(receiptRef)).thenReturn(ApiFutures.immediateFuture(receipt));
        when(transaction.get(visitRef)).thenReturn(ApiFutures.immediateFuture(visit));
        when(transaction.create(any(DocumentReference.class), anyMap())).thenReturn(transaction);
        when(transaction.update(any(DocumentReference.class), anyMap())).thenReturn(transaction);
        when(receiptRef.update(anyMap())).thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));
        when(db.runTransaction(any())).thenAnswer(invocation -> {
            Transaction.Function<Object> function = invocation.getArgument(0);
            try { return ApiFutures.immediateFuture(function.updateCallback(transaction)); }
            catch (Exception exception) { return ApiFutures.immediateFailedFuture(exception); }
        });
        ReflectionTestUtils.setField(service, "cachedStores", List.of(Map.of(
                "storeId", "store_a", "storeName", "경남식당", "address", "서울 중구",
                "latitude", 37.5, "longitude", 127.0)));
        when(receipt.exists()).thenReturn(true);
        when(receipt.getString("status")).thenReturn("PENDING");
        when(receipt.getString("userId")).thenReturn("user-1");
        // 이전 앱이 매장명을 ID 자리에 보낸 영수증도 정규 ID로 맞춰야 합니다.
        when(receipt.getString("storeId")).thenReturn("경남식당");
        when(receipt.getString("storeName")).thenReturn("경남식당");
        when(receipt.getString("menu")).thenReturn("백반");
        when(receipt.getLong("price")).thenReturn(7000L);
        when(receipt.getString("createdAt")).thenReturn("2026-09-30T14:50:00Z");
        when(receipt.get("imageUrls")).thenReturn(List.of());
    }

    @Test
    void approvalUsesTheSameDailyDocumentIdAsALocationVisit() throws Exception {
        when(receipt.getString("ocrDetectedDate")).thenReturn("2026-09-29");
        when(receipt.getBoolean("ocrReceiptDatePlausible")).thenReturn(true);

        service.approveReceiptVerification("receipt-1", "ADMIN");

        String locationId = service.locationVisitDocumentId("user-1",
                VisitRequest.builder().storeId("store_a").storeName("경남식당").build(), LocalDate.of(2026, 9, 29));
        verify(visits).document(locationId);
        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> data = ArgumentCaptor.forClass(Map.class);
        verify(transaction).create(eq(visitRef), data.capture());
        assertThat(data.getValue()).containsEntry("visitedAt", "2026-09-30T14:50:00Z")
                .containsEntry("visitDate", "2026-09-29").containsEntry("receiptId", "receipt-1")
                .containsEntry("storeId", "store_a");
        assertThat(data.getValue().get("approvedAt")).isNotNull().isNotEqualTo("2026-09-30T14:50:00Z");
    }

    @Test
    void withoutAPlausibleReceiptDateTheKoreanSubmissionDayIsUsed() throws Exception {
        when(receipt.getString("createdAt")).thenReturn("2026-09-30T15:30:00Z");
        when(receipt.getString("ocrDetectedDate")).thenReturn("2026-08-01");
        when(receipt.getBoolean("ocrReceiptDatePlausible")).thenReturn(false);

        service.approveReceiptVerification("receipt-1", "ADMIN");

        verify(visits).document(service.locationVisitDocumentId("user-1",
                VisitRequest.builder().storeId("store_a").build(), LocalDate.of(2026, 10, 1)));
    }

    @Test
    void anExistingVisitForTheSameStoreAndDayBlocksApproval() {
        when(visit.exists()).thenReturn(true);

        assertThatThrownBy(() -> service.approveReceiptVerification("receipt-1", "ADMIN"))
                .isInstanceOf(DuplicateVisitException.class);
        verify(transaction, never()).create(any(DocumentReference.class), anyMap());
        verify(transaction, never()).update(any(DocumentReference.class), anyMap());
    }

    @Test
    void submissionIsRefusedWhenTheSameDayVisitAlreadyExists() throws Exception {
        DocumentReference existingVisit = mock(DocumentReference.class);
        DocumentSnapshot existingSnapshot = mock(DocumentSnapshot.class);
        when(existingSnapshot.exists()).thenReturn(true);
        when(existingVisit.get()).thenReturn(ApiFutures.immediateFuture(existingSnapshot));
        LocalDate receiptDay = LocalDate.now(java.time.ZoneId.of("Asia/Seoul"));
        when(visits.document(service.dailyVisitDocumentId("user-1", "store_a", "경남식당", receiptDay)))
                .thenReturn(existingVisit);
        DocumentReference newReceipt = mock(DocumentReference.class);
        when(receipts.document(anyString())).thenReturn(newReceipt);
        ReceiptOcrService.Result ocr = new ReceiptOcrService.Result(true, 40, 7000, true, true, true,
                receiptDay.toString(), true, 100, "AUTO_APPROVED_CANDIDATE");

        assertThatThrownBy(() -> service.saveReceiptVerification("user-1", "store_a", "경남식당", "백반", 7000,
                "a".repeat(64), List.of("https://img/receipt.jpg"), ocr))
                .isInstanceOf(DuplicateVisitException.class);
        verify(newReceipt, never()).create(anyMap());
    }

    @Test
    void submissionRecordsTheVisitDateUsedForDuplicateChecks() throws Exception {
        DocumentReference noVisit = mock(DocumentReference.class);
        DocumentSnapshot missing = mock(DocumentSnapshot.class);
        when(noVisit.get()).thenReturn(ApiFutures.immediateFuture(missing));
        when(visits.document(anyString())).thenReturn(noVisit);
        DocumentReference newReceipt = mock(DocumentReference.class);
        when(receipts.document(anyString())).thenReturn(newReceipt);
        when(newReceipt.create(anyMap())).thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));
        when(newReceipt.getId()).thenReturn("receipt_new");
        String yesterday = LocalDate.now(java.time.ZoneId.of("Asia/Seoul")).minusDays(1).toString();
        ReceiptOcrService.Result ocr = new ReceiptOcrService.Result(true, 40, 7000, true, true, true,
                yesterday, true, 100, "AUTO_APPROVED_CANDIDATE");

        service.saveReceiptVerification("user-1", "store_a", "경남식당", "백반", 7000,
                "b".repeat(64), List.of("https://img/receipt.jpg"), ocr);

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> data = ArgumentCaptor.forClass(Map.class);
        verify(newReceipt).create(data.capture());
        assertThat(data.getValue()).containsEntry("visitDate", yesterday).containsEntry("status", "PENDING");
    }

    @Test
    void receiptVisitDateFallsBackToTheKoreanSubmissionDay() {
        assertThat(FirebaseService.receiptVisitDate("2026-10-01", true, "2026-10-03T00:00:00Z"))
                .isEqualTo(LocalDate.of(2026, 10, 1));
        assertThat(FirebaseService.receiptVisitDate("2026-10-01", false, "2026-09-30T15:30:00Z"))
                .isEqualTo(LocalDate.of(2026, 10, 1));
        assertThat(FirebaseService.receiptVisitDate("not-a-date", true, "2026-09-30T14:59:00Z"))
                .isEqualTo(LocalDate.of(2026, 9, 30));
    }

    @Test
    @SuppressWarnings("unchecked")
    void processedReceiptsAreMarkedForCleanupAndOnlyPendingOnesAreRetriedHourly() throws Exception {
        when(receipt.get("imageUrls")).thenReturn(List.of("https://img/receipt.jpg"));
        ReportImageStorage storage = (ReportImageStorage) ReflectionTestUtils.getField(service, "reportImageStorage");
        when(storage.deleteOwned(anyString(), any())).thenReturn(0);
        DocumentSnapshot afterFailure = mock(DocumentSnapshot.class);
        when(receiptRef.get()).thenReturn(ApiFutures.immediateFuture(afterFailure));

        service.rejectReceiptVerification("receipt-1", "흐린 사진", "ADMIN");

        ArgumentCaptor<Map<String, Object>> update = ArgumentCaptor.forClass(Map.class);
        verify(transaction).update(eq(receiptRef), update.capture());
        assertThat(update.getValue()).containsEntry("imageCleanupStatus", "PENDING");
        verify(receiptRef).update(Map.of("imageCleanupAttempts", 1L, "imageCleanupStatus", "PENDING"));

        Query pending = mock(Query.class);
        Query legacy = mock(Query.class);
        QuerySnapshot empty = mock(QuerySnapshot.class);
        when(empty.getDocuments()).thenReturn(List.<QueryDocumentSnapshot>of());
        when(receipts.whereEqualTo("imageCleanupStatus", "PENDING")).thenReturn(pending);
        when(pending.limit(100)).thenReturn(pending);
        when(pending.get()).thenReturn(ApiFutures.immediateFuture(empty));
        when(receipts.whereIn(eq("status"), anyList())).thenReturn(legacy);
        when(legacy.limit(500)).thenReturn(legacy);
        when(legacy.get()).thenReturn(ApiFutures.immediateFuture(empty));

        service.retryProcessedReceiptImageCleanup();
        service.retryProcessedReceiptImageCleanup();

        verify(pending, times(2)).get();
        verify(legacy, times(1)).get();
    }
}
