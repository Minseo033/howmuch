package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Transaction;
import com.howmuch.dto.UserReportRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** 계약 C7: 제보 수정은 요청에 없는 유형·대상·설명을 지우지 않고, 제보의 종류를 바꾸지 않습니다. */
class FirebaseServiceReportEditPreservationTest {
    private final Firestore db = mock(Firestore.class);
    private final Transaction transaction = mock(Transaction.class);
    private final DocumentReference reportRef = mock(DocumentReference.class);
    private final DocumentSnapshot existing = mock(DocumentSnapshot.class);
    private final FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));
    private Map<String, Object> stored;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() throws Exception {
        CollectionReference reports = mock(CollectionReference.class);
        when(db.collection("stores_user")).thenReturn(reports);
        when(reports.document("report_a")).thenReturn(reportRef);
        when(reportRef.get()).thenReturn(ApiFutures.immediateFuture(existing));
        when(transaction.get(reportRef)).thenReturn(ApiFutures.immediateFuture(existing));
        when(transaction.update(any(DocumentReference.class), anyMap())).thenReturn(transaction);
        when(db.runTransaction(any())).thenAnswer(invocation -> {
            Transaction.Function<Object> function = invocation.getArgument(0);
            try { return ApiFutures.immediateFuture(function.updateCallback(transaction)); }
            catch (Exception exception) { return ApiFutures.immediateFailedFuture(exception); }
        });
        when(existing.exists()).thenReturn(true);
        when(existing.getString("reporterId")).thenReturn("user-1");
        when(existing.getString("status")).thenAnswer(invocation -> stored.get("status"));
        when(existing.getData()).thenAnswer(invocation -> stored);
        ReflectionTestUtils.setField(service, "cachedStores", List.of(Map.of(
                "storeId", "store_a", "storeName", "국밥집", "address", "서울 중구",
                "menu1", "국밥", "price1", "8000", "latitude", 37.5, "longitude", 127.0)));
    }

    @Test
    void editingAPriceChangeWithoutIdentityFieldsKeepsTypeTargetAndDescription() throws Exception {
        stored = priceChangeReport();
        UserReportRequest edit = generalFormEdit();

        service.updateUserReport("report_a", "user-1", edit);

        Map<String, Object> written = capturedUpdate();
        assertThat(written).containsEntry("changeType", "rise").containsEntry("storeId", "store_a")
                .containsEntry("description", "메뉴판 가격이 올랐어요").containsEntry("reportType", null)
                .containsEntry("menu1", "국밥").containsEntry("price1", "9000")
                .containsEntry("status", "PENDING").containsEntry("processedAt", null)
                .containsEntry("reviewReason", null).containsEntry("rejectReason", null);
    }

    @Test
    void changingTheTypeOrTargetOfAnExistingStoreReportIsRejectedBeforeWriting() {
        stored = priceChangeReport();
        UserReportRequest changedType = generalFormEdit();
        changedType.setChangeType("drop");
        UserReportRequest changedStore = generalFormEdit();
        changedStore.setStoreId("store_b");
        UserReportRequest becameInfoReport = generalFormEdit();
        becameInfoReport.setReportType("STORE_INFO");

        for (UserReportRequest edit : List.of(changedType, changedStore, becameInfoReport)) {
            assertThatThrownBy(() -> service.updateUserReport("report_a", "user-1", edit))
                    .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("수정할 수 없어요");
        }
        verify(transaction, never()).update(any(DocumentReference.class), anyMap());
    }

    @Test
    void aNewStoreReportCannotTurnIntoAnExistingStoreReport() {
        stored = newStoreReport();
        UserReportRequest edit = generalFormEdit();
        edit.setChangeType("rise");

        assertThatThrownBy(() -> service.updateUserReport("report_a", "user-1", edit))
                .isInstanceOf(IllegalArgumentException.class);
        verify(transaction, never()).update(any(DocumentReference.class), anyMap());
    }

    @Test
    void newStoreEditKeepsItsIdentifierAndCoordinatesWhenGeocodingFails() throws Exception {
        stored = newStoreReport();
        UserReportRequest edit = generalFormEdit();
        edit.setStoreName("새 이름 식당");

        service.updateUserReport("report_a", "user-1", edit);

        Map<String, Object> written = capturedUpdate();
        assertThat(written).containsEntry("storeId", "store_user_original")
                .containsEntry("storeName", "새 이름 식당")
                .containsEntry("latitude", 35.1).containsEntry("longitude", 129.0)
                .containsEntry("cityProvince", "부산광역시").containsEntry("cityDistrict", "해운대구")
                .containsEntry("changeType", null).containsEntry("reportType", null);
    }

    @Test
    void preserveFillsOnlyMissingIdentityFields() {
        UserReportRequest request = new UserReportRequest();
        request.setDescription("새 설명");
        FirebaseService.preserveReportIdentity(Map.of("reportType", "STORE_INFO", "changeType", "closed",
                "storeId", "store_a", "description", "예전 설명"), request);
        assertThat(request.getReportType()).isEqualTo("STORE_INFO");
        assertThat(request.getChangeType()).isEqualTo("closed");
        assertThat(request.getStoreId()).isEqualTo("store_a");
        assertThat(request.getDescription()).isEqualTo("새 설명");
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> capturedUpdate() {
        ArgumentCaptor<Map<String, Object>> captor = ArgumentCaptor.forClass(Map.class);
        verify(transaction).update(eq(reportRef), captor.capture());
        return captor.getValue();
    }

    private Map<String, Object> priceChangeReport() {
        Map<String, Object> report = new HashMap<>();
        report.put("reporterId", "user-1");
        report.put("status", "REJECTED");
        report.put("storeId", "store_a");
        report.put("storeName", "국밥집");
        report.put("address", "서울 중구");
        report.put("changeType", "rise");
        report.put("description", "메뉴판 가격이 올랐어요");
        report.put("menu1", "국밥");
        report.put("price1", "9000");
        report.put("processedAt", "2026-10-01T00:00:00Z");
        report.put("reviewReason", "이전 검토 사유");
        report.put("rejectReason", "사진이 흐려요");
        report.put("createdAt", "2026-09-30T00:00:00Z");
        return report;
    }

    private Map<String, Object> newStoreReport() {
        Map<String, Object> report = new HashMap<>();
        report.put("reporterId", "user-1");
        report.put("status", "PENDING");
        report.put("storeId", "store_user_original");
        report.put("storeName", "옛 이름 식당");
        report.put("address", "부산 해운대구");
        report.put("latitude", 35.1);
        report.put("longitude", 129.0);
        report.put("cityProvince", "부산광역시");
        report.put("cityDistrict", "해운대구");
        report.put("createdAt", "2026-09-30T00:00:00Z");
        return report;
    }

    /** 일반 작성 화면처럼 changeType·storeId·description 없이 보내는 수정 요청 */
    private UserReportRequest generalFormEdit() {
        UserReportRequest edit = new UserReportRequest();
        edit.setStoreName("국밥집");
        edit.setAddress("서울 중구");
        edit.setMenu1("국밥");
        edit.setPrice1("9000");
        return edit;
    }
}

