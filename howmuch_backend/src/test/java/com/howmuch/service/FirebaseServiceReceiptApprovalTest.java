package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Transaction;
import com.google.cloud.firestore.WriteResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FirebaseServiceReceiptApprovalTest {

    private Firestore db;
    private Transaction transaction;
    private DocumentReference receiptRef;
    private DocumentReference visitRef;
    private DocumentSnapshot receipt;
    private ReportImageStorage imageStorage;
    private FirebaseService service;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() throws Exception {
        db = mock(Firestore.class);
        transaction = mock(Transaction.class);
        receiptRef = mock(DocumentReference.class);
        visitRef = mock(DocumentReference.class);
        receipt = mock(DocumentSnapshot.class);
        imageStorage = mock(ReportImageStorage.class);
        CollectionReference receipts = mock(CollectionReference.class);
        CollectionReference visits = mock(CollectionReference.class);

        when(db.collection("receipt_verifications")).thenReturn(receipts);
        when(db.collection("visits")).thenReturn(visits);
        when(receipts.document("receipt-1")).thenReturn(receiptRef);
        when(visits.document()).thenReturn(visitRef);
        when(visitRef.getId()).thenReturn("visit-1");
        when(transaction.get(receiptRef)).thenReturn(ApiFutures.immediateFuture(receipt));
        when(transaction.set(any(DocumentReference.class), anyMap())).thenReturn(transaction);
        when(transaction.update(any(DocumentReference.class), anyMap())).thenReturn(transaction);
        when(receiptRef.update(anyMap())).thenReturn(
                ApiFutures.immediateFuture(mock(WriteResult.class)));
        when(db.runTransaction(any())).thenAnswer(invocation -> {
            Transaction.Function<Object> function = invocation.getArgument(0);
            try {
                return ApiFutures.immediateFuture(function.updateCallback(transaction));
            } catch (Exception e) {
                return ApiFutures.immediateFailedFuture(e);
            }
        });
        service = new FirebaseService(db, imageStorage);
    }

    @Test
    @SuppressWarnings("unchecked")
    void createsVisitAndMarksReceiptApprovedInOneTransaction() throws Exception {
        when(receipt.exists()).thenReturn(true);
        when(receipt.getString("status")).thenReturn("PENDING");
        when(receipt.getString("userId")).thenReturn("user-1");
        when(receipt.getString("storeId")).thenReturn("store-1");
        when(receipt.getString("storeName")).thenReturn("테스트 식당");
        when(receipt.getString("menu")).thenReturn("국밥");
        when(receipt.getLong("price")).thenReturn(6000L);
        mockUsableOcrEvidence();
        when(receipt.get("imageUrls")).thenReturn(java.util.List.of("owned-receipt-url"));
        when(imageStorage.deleteOwned(eq("user-1"), anyCollection()))
                .thenReturn(1);

        Map<String, Object> result = service.approveReceiptVerification("receipt-1", "ADMIN");

        assertThat(result).containsEntry("visitId", "visit-1");
        ArgumentCaptor<Map<String, Object>> visitData = ArgumentCaptor.forClass(Map.class);
        verify(transaction).set(eq(visitRef), visitData.capture());
        assertThat(visitData.getValue())
                .containsEntry("userId", "user-1")
                .containsEntry("verificationMethod", "RECEIPT_OCR");
        ArgumentCaptor<Map<String, Object>> receiptUpdate = ArgumentCaptor.forClass(Map.class);
        verify(transaction).update(eq(receiptRef), receiptUpdate.capture());
        assertThat(receiptUpdate.getValue())
                .containsEntry("status", "APPROVED")
                .containsEntry("visitId", "visit-1");
        verify(imageStorage).deleteOwned(eq("user-1"), argThat(urls ->
                urls.size() == 1 && urls.contains("owned-receipt-url")));
        verify(receiptRef).update(argThat(update ->
                "DELETED".equals(update.get("imageCleanupStatus"))
                        && java.util.List.of().equals(update.get("imageUrls"))));
    }

    @Test
    void refusesAnAlreadyProcessedReceiptWithoutCreatingAnotherVisit() {
        when(receipt.exists()).thenReturn(true);
        when(receipt.getString("status")).thenReturn("APPROVED");

        assertThatThrownBy(() -> service.approveReceiptVerification("receipt-1", "ADMIN"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("이미 처리된");
        verify(transaction, never()).set(any(DocumentReference.class), anyMap());
    }

    @Test
    void refusesReceiptApprovalWhenTheOcrProviderWasUnavailable() {
        when(receipt.exists()).thenReturn(true);
        when(receipt.getString("status")).thenReturn("PENDING");
        when(receipt.getBoolean("ocrProviderAvailable")).thenReturn(false);
        when(receipt.getString("ocrStatus")).thenReturn("OCR_NOT_CONFIGURED");

        assertThatThrownBy(() -> service.approveReceiptVerification("receipt-1", "ADMIN"))
                .isInstanceOf(ReceiptOcrEvidenceException.class)
                .hasMessageContaining("OCR 판독이 완료되지 않은");
        verify(transaction, never()).set(any(DocumentReference.class), anyMap());
        verify(transaction, never()).update(any(DocumentReference.class), anyMap());
    }

    @Test
    void refusesReceiptApprovalWhenRequiredOcrEvidenceIsMissing() {
        when(receipt.exists()).thenReturn(true);
        when(receipt.getString("status")).thenReturn("PENDING");
        when(receipt.getBoolean("ocrProviderAvailable")).thenReturn(true);
        when(receipt.getLong("ocrDetectedTextLength")).thenReturn(24L);
        when(receipt.getLong("ocrDetectedPrice")).thenReturn(7000L);
        when(receipt.getString("ocrDetectedDate")).thenReturn(null);

        assertThatThrownBy(() -> service.approveReceiptVerification("receipt-1", "ADMIN"))
                .isInstanceOf(ReceiptOcrEvidenceException.class);
        verify(transaction, never()).set(any(DocumentReference.class), anyMap());
    }

    private void mockUsableOcrEvidence() {
        when(receipt.getBoolean("ocrProviderAvailable")).thenReturn(true);
        when(receipt.getLong("ocrDetectedTextLength")).thenReturn(42L);
        when(receipt.getLong("ocrDetectedPrice")).thenReturn(6000L);
        when(receipt.getString("ocrDetectedDate")).thenReturn("2026-08-29");
    }

    @Test
    @SuppressWarnings("unchecked")
    void rejectsPendingReceiptInsideTransaction() throws Exception {
        when(receipt.exists()).thenReturn(true);
        when(receipt.getString("status")).thenReturn("PENDING");
        when(receipt.getString("userId")).thenReturn("user-1");
        when(receipt.get("imageUrls")).thenReturn(java.util.List.of());

        service.rejectReceiptVerification("receipt-1", "날짜 확인 불가", "ADMIN");

        ArgumentCaptor<Map<String, Object>> update = ArgumentCaptor.forClass(Map.class);
        verify(transaction).update(eq(receiptRef), update.capture());
        assertThat(update.getValue())
                .containsEntry("status", "REJECTED")
                .containsEntry("rejectReason", "날짜 확인 불가");
        verify(transaction, never()).set(any(DocumentReference.class), anyMap());
    }

    @Test
    void refusesToRejectAnAlreadyApprovedReceipt() {
        when(receipt.exists()).thenReturn(true);
        when(receipt.getString("status")).thenReturn("APPROVED");

        assertThatThrownBy(() -> service.rejectReceiptVerification(
                "receipt-1", "반려", "ADMIN"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("이미 처리된");
    }
}
