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
import com.google.cloud.firestore.WriteBatch;
import com.google.cloud.firestore.WriteResult;
import com.howmuch.dto.NotificationResponseDto;
import com.howmuch.dto.NotificationSettingsDto;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** 계약 C3: 알림 대상 필드, 일괄 읽음, 푸시 토글 매핑, 제보 승인·반려 알림, 가격 알림 방향(BE-CORE-17). */
class FirebaseServiceNotificationContractTest {
    private final Firestore db = mock(Firestore.class);
    private final FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

    @Test
    void notificationListCarriesTargetIdentifiers() throws Exception {
        CollectionReference notifications = mock(CollectionReference.class);
        Query byUser = mock(Query.class);
        Query ordered = mock(Query.class);
        Query limited = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(db.collection("notifications")).thenReturn(notifications);
        when(notifications.whereEqualTo("userId", "user-1")).thenReturn(byUser);
        when(byUser.orderBy("createdAt", Query.Direction.DESCENDING)).thenReturn(ordered);
        when(ordered.limit(100)).thenReturn(limited);
        when(limited.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        QueryDocumentSnapshot comment = notification("n1", Map.of("type", "FEED_COMMENT", "relatedPostId", "post-1",
                "createdAt", "2026-10-03T00:00:00Z"));
        QueryDocumentSnapshot price = notification("n2", Map.of("type", "PRICE_ALERT", "relatedReportId", "report-1",
                "storeId", "store_a", "createdAt", "2026-10-02T00:00:00Z"));
        QueryDocumentSnapshot notice = notification("n3", Map.of("type", "notice", "createdAt", "2026-10-01T00:00:00Z"));
        List<QueryDocumentSnapshot> documents = List.of(comment, price, notice);
        when(snapshot.getDocuments()).thenReturn(documents);

        List<NotificationResponseDto> result = service.getNotifications("user-1");

        assertThat(result).extracting(NotificationResponseDto::getRelatedPostId).containsExactly("post-1", null, null);
        assertThat(result).extracting(NotificationResponseDto::getRelatedReportId).containsExactly(null, "report-1", null);
        assertThat(result).extracting(NotificationResponseDto::getStoreId).containsExactly(null, "store_a", null);
    }

    @Test
    void markAllReadUpdatesOnlyTheCallersUnreadNotificationsInOneBatch() throws Exception {
        CollectionReference notifications = mock(CollectionReference.class);
        Query byUser = mock(Query.class);
        Query unread = mock(Query.class);
        Query limited = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(db.collection("notifications")).thenReturn(notifications);
        when(notifications.whereEqualTo("userId", "user-1")).thenReturn(byUser);
        when(byUser.whereEqualTo("isRead", false)).thenReturn(unread);
        when(unread.limit(500)).thenReturn(limited);
        when(limited.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        QueryDocumentSnapshot mine = notification("n1", Map.of("userId", "user-1"));
        QueryDocumentSnapshot alsoMine = notification("n2", Map.of("userId", "user-1"));
        QueryDocumentSnapshot foreign = notification("n3", Map.of("userId", "user-2"));
        DocumentReference mineRef = mock(DocumentReference.class);
        DocumentReference alsoMineRef = mock(DocumentReference.class);
        DocumentReference foreignRef = mock(DocumentReference.class);
        when(mine.getReference()).thenReturn(mineRef);
        when(alsoMine.getReference()).thenReturn(alsoMineRef);
        when(foreign.getReference()).thenReturn(foreignRef);
        List<QueryDocumentSnapshot> documents = List.of(mine, alsoMine, foreign);
        when(snapshot.getDocuments()).thenReturn(documents);
        WriteBatch batch = mock(WriteBatch.class);
        when(db.batch()).thenReturn(batch);
        when(batch.commit()).thenReturn(ApiFutures.immediateFuture(List.of()));

        assertThat(service.markAllNotificationsAsRead("user-1")).isEqualTo(2);

        verify(batch).update(mineRef, "isRead", true);
        verify(batch).update(alsoMineRef, "isRead", true);
        verify(batch, never()).update(eq(foreignRef), anyString(), any());
        verify(batch).commit();
    }

    @Test
    void pushTogglesFollowTheNotificationCategory() {
        NotificationSettingsDto reviewOnly = settings(true, false, false);
        NotificationSettingsDto reportOnly = settings(false, true, false);
        NotificationSettingsDto priceOnly = settings(false, false, true);
        NotificationSettingsDto none = settings(false, false, false);

        assertThat(push(reviewOnly, "FEED_COMMENT")).isTrue();
        assertThat(push(reportOnly, "FEED_COMMENT")).isFalse();
        assertThat(push(reportOnly, "INQUIRY_ANSWER")).isTrue();
        assertThat(push(reportOnly, "REPORT_APPROVED")).isTrue();
        assertThat(push(reviewOnly, "REPORT_REJECTED")).isFalse();
        assertThat(push(priceOnly, "PRICE_ALERT")).isTrue();
        assertThat(push(reportOnly, "PRICE_ALERT")).isFalse();
        assertThat(push(priceOnly, "notice")).isTrue();
        assertThat(push(reviewOnly, "general")).isTrue();
        assertThat(push(none, "notice")).isFalse();
    }

    @Test
    void approvalAndRejectionLeaveADeterministicNotificationForTheReporter() throws Exception {
        Transaction transaction = mock(Transaction.class);
        CollectionReference reports = mock(CollectionReference.class);
        DocumentReference reportRef = mock(DocumentReference.class);
        DocumentSnapshot reportSnapshot = mock(DocumentSnapshot.class);
        when(db.collection("stores_user")).thenReturn(reports);
        when(reports.document("report_new")).thenReturn(reportRef);
        when(transaction.get(reportRef)).thenReturn(ApiFutures.immediateFuture(reportSnapshot));
        when(transaction.update(any(DocumentReference.class), anyMap())).thenReturn(transaction);
        when(db.runTransaction(any())).thenAnswer(invocation -> {
            Transaction.Function<Object> function = invocation.getArgument(0);
            try { return ApiFutures.immediateFuture(function.updateCallback(transaction)); }
            catch (Exception exception) { return ApiFutures.immediateFailedFuture(exception); }
        });
        Map<String, Object> report = new HashMap<>(Map.of("storeId", "store_user_1", "storeName", "새식당",
                "address", "서울 중구", "menu1", "국밥", "price1", "8000", "status", "PENDING", "reporterId", "user-9"));
        when(reportSnapshot.exists()).thenReturn(true);
        when(reportSnapshot.getData()).thenAnswer(invocation -> report);
        when(reportSnapshot.getString(anyString())).thenAnswer(invocation -> (String) report.get(invocation.getArgument(0)));
        CollectionReference notifications = mock(CollectionReference.class);
        DocumentReference notificationRef = mock(DocumentReference.class);
        when(db.collection("notifications")).thenReturn(notifications);
        when(notifications.document(anyString())).thenReturn(notificationRef);
        when(notificationRef.create(anyMap())).thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));

        service.approveReport("report_new");

        ArgumentCaptor<String> approvedId = ArgumentCaptor.forClass(String.class);
        verify(notifications).document(approvedId.capture());
        assertThat(approvedId.getValue()).startsWith("report_approved_report__new_");
        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> approved = ArgumentCaptor.forClass(Map.class);
        verify(notificationRef).create(approved.capture());
        assertThat(approved.getValue()).containsEntry("userId", "user-9").containsEntry("type", "REPORT_APPROVED")
                .containsEntry("relatedReportId", "report_new").containsEntry("storeId", "store_user_1")
                .containsEntry("isRead", false);
        assertThat(String.valueOf(approved.getValue().get("body"))).contains("새식당").contains("지도에 등록");

        report.put("status", "PENDING");
        service.rejectReport("report_new", "메뉴판 사진이 흐려요");

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> both = ArgumentCaptor.forClass(Map.class);
        verify(notificationRef, org.mockito.Mockito.times(2)).create(both.capture());
        Map<String, Object> rejected = both.getAllValues().get(1);
        assertThat(rejected).containsEntry("type", "REPORT_REJECTED").containsEntry("relatedReportId", "report_new");
        assertThat(String.valueOf(rejected.get("body"))).contains("메뉴판 사진이 흐려요");
    }

    @Test
    void priceAlertDirectionComesFromTheAppliedBeforeAndAfterValues() {
        assertThat(FirebaseService.priceChangeDirection(
                Map.of("menu1", "국밥", "price1", "6000", "free1", false),
                Map.of("menu1", "국밥", "price1", "6500", "free1", false))).isEqualTo("rise");
        assertThat(FirebaseService.priceChangeDirection(
                Map.of("menu2", "국밥", "price2", "6000"), Map.of("menu2", "국밥", "price2", "5500"))).isEqualTo("drop");
        assertThat(FirebaseService.priceChangeDirection(
                Map.of("menu1", "국밥", "price1", "6000"), Map.of("menu1", "국밥", "price1", "6000"))).isNull();
        assertThat(FirebaseService.priceChangeDirection(
                Map.of("menu3", "", "price3", ""), Map.of("menu3", "냉면", "price3", "7000"))).isEqualTo("new");
        assertThat(FirebaseService.priceChangeDirection(
                Map.of("menu1", "국밥", "price1", "6000"), Map.of("menu1", "", "price1", ""))).isEqualTo("delete");
        assertThat(FirebaseService.priceChangeDirection(
                Map.of("menu1", "국밥", "price1", "6000~7000"), Map.of("menu1", "국밥", "price1", "6500"))).isEqualTo("change");
        assertThat(FirebaseService.priceChangeDirection(Map.of(), Map.of())).isNull();
    }

    @Test
    void priceAlertConditionsAreAppliedToEveryDirection() {
        NotificationSettingsDto riseOnly = NotificationSettingsDto.builder()
                .notifyOnRise(true).notifyOnDrop(false).notifyOnNewMenu(false).build();
        NotificationSettingsDto newMenuOnly = NotificationSettingsDto.builder()
                .notifyOnRise(false).notifyOnDrop(false).notifyOnNewMenu(true).build();

        assertThat(shouldNotify(riseOnly, "rise")).isTrue();
        assertThat(shouldNotify(riseOnly, "drop")).isFalse();
        assertThat(shouldNotify(riseOnly, "delete")).isTrue();
        assertThat(shouldNotify(newMenuOnly, "delete")).isFalse();
        assertThat(shouldNotify(newMenuOnly, "new")).isTrue();
        assertThat(shouldNotify(newMenuOnly, "price_mismatch")).isFalse();
        assertThat(shouldNotify(riseOnly, null)).isFalse();
    }

    private boolean shouldNotify(NotificationSettingsDto settings, String direction) {
        return Boolean.TRUE.equals(ReflectionTestUtils.invokeMethod(service, "shouldNotifyPriceChange", settings, direction));
    }

    private boolean push(NotificationSettingsDto settings, String type) {
        return Boolean.TRUE.equals(ReflectionTestUtils.invokeMethod(service, "isPushTypeEnabled", settings, type));
    }

    private NotificationSettingsDto settings(boolean review, boolean report, boolean price) {
        return NotificationSettingsDto.builder().all(true).review(review).report(report).price(price)
                .todayPick(false).quietHours(false).quietStart("22:00").quietEnd("08:00").build();
    }

    private QueryDocumentSnapshot notification(String id, Map<String, Object> data) {
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        when(document.getId()).thenReturn(id);
        when(document.getData()).thenReturn(new HashMap<>(data));
        when(document.getString("userId")).thenReturn((String) data.get("userId"));
        return document;
    }
}

