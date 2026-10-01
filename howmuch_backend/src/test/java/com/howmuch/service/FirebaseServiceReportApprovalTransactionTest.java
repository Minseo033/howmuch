package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.google.cloud.firestore.Transaction;
import com.howmuch.dto.ReportApprovalRequest;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Exercises the service's real Firestore transaction callback, not just its pure policy. */
class FirebaseServiceReportApprovalTransactionTest {
    private Firestore db;
    private Transaction transaction;
    private DocumentReference reportRef;
    private DocumentReference correctionRef;
    private DocumentSnapshot reportSnapshot;
    private DocumentSnapshot correctionSnapshot;
    private CollectionReference corrections;
    private FirebaseService service;
    private Map<String, Object> report;
    private final Map<String, Object> original = Map.of("storeId", "store_a", "storeName", "국밥집",
            "menu1", "국밥", "price1", "6000", "address", "서울 중구", "latitude", 37.5, "longitude", 127.0);

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setup() throws Exception {
        db = mock(Firestore.class); transaction = mock(Transaction.class);
        reportRef = mock(DocumentReference.class); correctionRef = mock(DocumentReference.class);
        reportSnapshot = mock(DocumentSnapshot.class); correctionSnapshot = mock(DocumentSnapshot.class);
        CollectionReference reports = mock(CollectionReference.class); corrections = mock(CollectionReference.class);
        when(db.collection("stores_user")).thenReturn(reports);
        when(db.collection("store_corrections")).thenReturn(corrections);
        when(reports.document("report_a")).thenReturn(reportRef);
        when(corrections.document("store_a")).thenReturn(correctionRef);
        when(transaction.get(reportRef)).thenReturn(ApiFutures.immediateFuture(reportSnapshot));
        when(transaction.get(correctionRef)).thenReturn(ApiFutures.immediateFuture(correctionSnapshot));
        when(transaction.set(any(DocumentReference.class), anyMap())).thenReturn(transaction);
        when(transaction.update(any(DocumentReference.class), anyMap())).thenReturn(transaction);
        when(db.runTransaction(any())).thenAnswer(invocation -> {
            Transaction.Function<Object> function = invocation.getArgument(0);
            try { return ApiFutures.immediateFuture(function.updateCallback(transaction)); }
            catch (Exception exception) { return ApiFutures.immediateFailedFuture(exception); }
        });
        report = new HashMap<>(Map.of("id", "report_a", "storeId", "store_a", "storeName", "국밥집",
                "status", "PENDING", "reportType", "STORE_INFO", "changeType", "price_mismatch"));
        when(reportSnapshot.exists()).thenReturn(true);
        when(reportSnapshot.getData()).thenAnswer(invocation -> report);
        when(reportSnapshot.getString("status")).thenAnswer(invocation -> report.get("status"));
        service = new FirebaseService(db, mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(service, "cachedStores", List.of(original));
        ReflectionTestUtils.setField(service, "cachedUserStores", List.of(report));
    }

    private ReportApprovalRequest approval(String resolution, Map<String, Object> after) {
        var request = new ReportApprovalRequest(); request.setResolution(resolution);
        request.setReviewReason("원본 자료와 변경 내용 검토 완료"); request.setExpectedRevision(0L);
        var current = service.getStoreById("store_a");
        var before = new HashMap<String, Object>();
        for (String key : List.of("storeId", "storeName", "address", "latitude", "longitude", "isClosed", "correctionRevision")) {
            if (current.containsKey(key)) before.put(key, current.get(key));
        }
        for (int slot = 1; slot <= 4; slot++) for (String prefix : List.of("menu", "price", "free")) {
            String key = prefix + slot; before.put(key, current.get(key));
        }
        request.setBefore(before); request.setAfter(after);
        return request;
    }

    @Test
    @SuppressWarnings("unchecked")
    void correctionAndModerationAreWrittenInTheSameTransactionBeforeCachePublication() throws Exception {
        var request = approval("PRICE", Map.of("menuSlot", 1, "menu", "국밥", "price", "6500", "free", false));
        service.approveReport("report_a", request);
        ArgumentCaptor<Map<String, Object>> correction = ArgumentCaptor.forClass(Map.class);
        ArgumentCaptor<Map<String, Object>> update = ArgumentCaptor.forClass(Map.class);
        var order = inOrder(transaction);
        order.verify(transaction).get(reportRef); order.verify(transaction).get(correctionRef);
        order.verify(transaction).set(eq(correctionRef), correction.capture());
        order.verify(transaction).update(eq(reportRef), update.capture());
        assertThat(correction.getValue()).containsEntry("revision", 1L).containsEntry("lastReportId", "report_a");
        assertThat((Map<String, Object>) correction.getValue().get("fields")).containsEntry("price1", "6500");
        assertThat(update.getValue()).containsEntry("status", "APPROVED").containsEntry("resolution", "PRICE")
                .containsEntry("previousFields", Map.of("menu1", "국밥", "price1", "6000", "free1", false));
        assertThat(service.getStoreById("store_a")).containsEntry("price1", "6500").containsEntry("source", "GOV")
                .containsEntry("correctionRevision", 1L).doesNotContainKeys("reviewReason", "approvedBy", "lastReportId");
        assertThat(original).containsEntry("price1", "6000");
        assertThat(service.getPriceHistory("store_a", "국밥").get("history")).asList().hasSize(1);
        verifyNoInteractions(reportRef, correctionRef); // Only transaction writes, never separate document writes.
    }

    @Test void duplicateApprovalQueuesNoWrites() {
        report.put("status", "APPROVED");
        assertThatThrownBy(() -> service.approveReport("report_a", approval("CLOSED", Map.of("isClosed", true))))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("이미 처리");
        verify(transaction, never()).set(any(DocumentReference.class), anyMap());
        verify(transaction, never()).update(any(DocumentReference.class), anyMap());
    }

    @Test void staleRevisionOrBeforePriceQueuesNoWritesAndDoesNotPublishACache() {
        when(correctionSnapshot.exists()).thenReturn(true);
        when(correctionSnapshot.getData()).thenReturn(Map.of("fields", Map.of("price1", "6200"), "revision", 1L));
        assertThatThrownBy(() -> service.approveReport("report_a", approval("CLOSED", Map.of("isClosed", true))))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("변경");
        verify(transaction, never()).set(any(DocumentReference.class), anyMap());
        verify(transaction, never()).update(any(DocumentReference.class), anyMap());
        assertThat(service.getStoreById("store_a")).containsEntry("price1", "6000");
    }

    @Test void changedBeforeValueAtTheSameRevisionQueuesNoWrites() {
        var request = approval("PRICE", Map.of("menuSlot", 1, "menu", "국밥", "price", "6500", "free", false));
        var before = new HashMap<>(request.getBefore()); before.put("price1", "5500"); request.setBefore(before);
        assertThatThrownBy(() -> service.approveReport("report_a", request)).isInstanceOf(IllegalStateException.class);
        verify(transaction, never()).set(any(DocumentReference.class), anyMap());
        verify(transaction, never()).update(any(DocumentReference.class), anyMap());
    }

    @Test void ordinaryPriceRejectsStaleRevisionAndLegacyReportAfterAnyCorrection() {
        report.remove("reportType"); report.put("changeType", "rise"); report.put("menu1", "국밥"); report.put("price1", "6500");
        when(correctionSnapshot.exists()).thenReturn(true);
        when(correctionSnapshot.getData()).thenReturn(Map.of("fields", Map.of("price1", "6200"), "revision", 1L));
        assertThatThrownBy(() -> service.approveReport("report_a")).isInstanceOf(IllegalStateException.class);
        report.put("baseRevision", 0L);
        assertThatThrownBy(() -> service.approveReport("report_a")).isInstanceOf(IllegalStateException.class);
        verify(transaction, never()).set(any(DocumentReference.class), anyMap());
        verify(transaction, never()).update(any(DocumentReference.class), anyMap());
    }

    @Test void noChangeIsExplicitlyModeratedWithoutCreatingAnOverride() throws Exception {
        service.approveReport("report_a", approval("NO_CHANGE", Map.of()));
        verify(transaction, never()).set(any(DocumentReference.class), anyMap());
        verify(transaction).update(eq(reportRef), argThat(update -> "APPROVED".equals(update.get("status"))
                && "NO_CHANGE".equals(update.get("resolution")) && update.get("reviewReason") != null));
        assertThat(service.getStoreById("store_a")).containsEntry("price1", "6000");
    }

    @Test void invalidNewStoreZeroCannotBeApprovedBypassingSubmissionValidation() {
        report.remove("reportType"); report.remove("changeType"); report.put("menu1", "국밥"); report.put("price1", "0");
        assertThatThrownBy(() -> service.approveReport("report_a")).isInstanceOf(IllegalArgumentException.class);
        verify(transaction, never()).set(any(DocumentReference.class), anyMap());
        verify(transaction, never()).update(any(DocumentReference.class), anyMap());
    }

    @Test
    @SuppressWarnings("unchecked")
    void committedCorrectionReloadsAfterRestartWithoutInternalFieldsLeaking() throws Exception {
        service.approveReport("report_a", approval("LOCATION", Map.of("address", "서울 종로구", "latitude", 37.6, "longitude", 127.1)));
        ArgumentCaptor<Map<String, Object>> persisted = ArgumentCaptor.forClass(Map.class);
        verify(transaction).set(eq(correctionRef), persisted.capture());
        QueryDocumentSnapshot doc = mock(QueryDocumentSnapshot.class); QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(doc.getId()).thenReturn("store_a"); when(doc.getData()).thenReturn(persisted.getValue());
        when(snapshot.getDocuments()).thenReturn(List.of(doc)); when(corrections.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        FirebaseService restarted = new FirebaseService(db, mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(restarted, "cachedStores", List.of(original));
        ReflectionTestUtils.invokeMethod(restarted, "loadStoreCorrections");
        assertThat(restarted.getStoreById("store_a")).containsEntry("address", "서울 종로구")
                .containsEntry("latitude", 37.6).containsEntry("source", "GOV").doesNotContainKeys("updatedAt", "lastReportId");
        assertThat(restarted.getGovStoresSnapshot().getFirst()).containsEntry("address", "서울 중구");
    }

    @Test void delayedRefreshCannotOverwriteANewerLocalCommitOrDropItsRecord() throws Exception {
        QueryDocumentSnapshot doc = mock(QueryDocumentSnapshot.class); QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(doc.getId()).thenReturn("store_a"); when(doc.getData()).thenReturn(Map.of("fields", Map.of("price1", "6100"), "revision", 1L));
        when(snapshot.getDocuments()).thenReturn(List.of(doc)); when(corrections.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        ReflectionTestUtils.setField(service, "cachedStoreCorrections", Map.of("store_a", Map.of("fields", Map.of("price1", "6500"), "revision", 2L)));
        ReflectionTestUtils.invokeMethod(service, "loadStoreCorrections");
        assertThat(service.getStoreById("store_a")).containsEntry("price1", "6500").containsEntry("correctionRevision", 2L);
        when(snapshot.getDocuments()).thenReturn(List.of());
        ReflectionTestUtils.invokeMethod(service, "loadStoreCorrections");
        assertThat(service.getStoreById("store_a")).containsEntry("price1", "6500");
    }

    @Test void editCannotUndoApprovalThatCommitsAfterItsInitialDocumentRead() {
        when(reportRef.get()).thenReturn(ApiFutures.immediateFuture(reportSnapshot));
        when(reportSnapshot.getString("reporterId")).thenReturn("user-1");
        DocumentSnapshot latest = mock(DocumentSnapshot.class);
        when(latest.exists()).thenReturn(true); when(latest.getString("reporterId")).thenReturn("user-1");
        when(latest.getString("status")).thenReturn("APPROVED");
        when(transaction.get(reportRef)).thenReturn(ApiFutures.immediateFuture(latest));
        var edit = new com.howmuch.dto.UserReportRequest(); edit.setStoreId("store_a"); edit.setStoreName("국밥집");
        edit.setReportType("STORE_INFO"); edit.setChangeType("other"); edit.setAddress("서울 중구");
        assertThatThrownBy(() -> service.updateUserReport("report_a", "user-1", edit))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("승인");
        verify(transaction, never()).update(any(DocumentReference.class), anyMap());
    }

    @Test
    @SuppressWarnings("unchecked")
    void lateEditCachePublicationDoesNotUndoAnApprovedStatus() throws Exception {
        when(reportRef.get()).thenReturn(ApiFutures.immediateFuture(reportSnapshot));
        when(reportSnapshot.getString("reporterId")).thenReturn("user-1");
        when(db.runTransaction(any())).thenAnswer(invocation -> {
            Transaction.Function<Object> function = invocation.getArgument(0);
            Object result = function.updateCallback(transaction);
            ReflectionTestUtils.invokeMethod(service, "updateReportCache", "report_a", Map.of("status", "APPROVED"));
            return ApiFutures.immediateFuture(result);
        });
        var edit = new com.howmuch.dto.UserReportRequest(); edit.setStoreId("store_a"); edit.setStoreName("국밥집");
        edit.setReportType("STORE_INFO"); edit.setChangeType("other"); edit.setAddress("서울 중구");
        service.updateUserReport("report_a", "user-1", edit);
        var cached = (List<Map<String, Object>>) ReflectionTestUtils.getField(service, "cachedUserStores");
        assertThat(cached.getFirst()).containsEntry("status", "APPROVED");
    }

    @Test
    @SuppressWarnings("unchecked")
    void delayedReportQueryCannotRestorePendingStatusAfterAnApproval() {
        CollectionReference reports = db.collection("stores_user");
        QuerySnapshot snapshot = mock(QuerySnapshot.class); QueryDocumentSnapshot doc = mock(QueryDocumentSnapshot.class);
        when(doc.getId()).thenReturn("report_a"); when(doc.getData()).thenReturn(report);
        when(snapshot.getDocuments()).thenReturn(List.of(doc));
        when(reports.get()).thenAnswer(invocation -> {
            ReflectionTestUtils.invokeMethod(service, "updateReportCache", "report_a", Map.of("status", "APPROVED"));
            return ApiFutures.immediateFuture(snapshot);
        });
        ReflectionTestUtils.invokeMethod(service, "loadUserStoresFromFirestore");
        var cached = (List<Map<String, Object>>) ReflectionTestUtils.getField(service, "cachedUserStores");
        assertThat(cached.getFirst()).containsEntry("status", "APPROVED");
    }
}
