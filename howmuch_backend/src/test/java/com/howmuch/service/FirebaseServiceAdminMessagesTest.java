package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.google.cloud.firestore.WriteBatch;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** QA 2026-10-07 #3: 관리자가 보낸 공지·알림을 발송 단위로 보고, 회수하면 회원 알림함에서 사라집니다. */
class FirebaseServiceAdminMessagesTest {
    private static final String NOTICE_AT = "2026-09-10T06:00:00.123456Z";
    private static final String LEGACY_AT = "2026-08-20T01:00:00.5Z";

    private Firestore db;
    private CollectionReference notifications;
    private CollectionReference users;
    private FirebaseService service;

    @BeforeEach
    void setUp() {
        db = mock(Firestore.class);
        notifications = mock(CollectionReference.class);
        users = mock(CollectionReference.class);
        when(db.collection("notifications")).thenReturn(notifications);
        when(db.collection("users")).thenReturn(users);
        service = new FirebaseService(db, mock(ReportImageStorage.class));
    }

    @Test
    @SuppressWarnings("unchecked")
    void eachBroadcastIsListedOnceWithItsRecipientsNewestFirst() throws Exception {
        stubNoticeScan(List.of(
                doc("n1", notice("u1", "점검 안내", "내일 점검합니다.", NOTICE_AT, true)),
                doc("n2", notice("u2", "점검 안내", "내일 점검합니다.", NOTICE_AT, false)),
                doc("n3", legacy("u1", "dd", "테스트", LEGACY_AT)),
                doc("n4", Map.of("userId", "u2", "type", "notice", "title", "시각 없음"))));
        stubUser("u1", Map.of("nickname", "기미서"));

        Map<String, Object> result = service.listAdminMessages(FirebaseService.AdminMessageKind.NOTICE);

        List<Map<String, Object>> items = (List<Map<String, Object>>) result.get("items");
        assertThat(items).extracting(item -> item.get("title")).containsExactly("점검 안내", "dd");
        assertThat(items.get(0)).containsEntry("recipients", 2).containsEntry("readCount", 1)
                .containsEntry("type", "notice").containsEntry("createdAt", NOTICE_AT)
                .doesNotContainKeys("targetUid", "targetName");
        assertThat(String.valueOf(items.get(0).get("id"))).startsWith(NOTICE_AT + "~");
        assertThat(items.get(1)).containsEntry("recipients", 1).containsEntry("type", "admin")
                .containsEntry("targetUid", "u1").containsEntry("targetName", "기미서");
        assertThat(result).containsEntry("truncated", false);
    }

    @Test
    @SuppressWarnings("unchecked")
    void recallingANoticeDeletesOnlyThatBroadcastFromEveryInbox() throws Exception {
        QueryDocumentSnapshot first = doc("n1", notice("u1", "점검 안내", "내일 점검합니다.", NOTICE_AT, true));
        QueryDocumentSnapshot second = doc("n2", notice("u2", "점검 안내", "내일 점검합니다.", NOTICE_AT, false));
        stubNoticeScan(List.of(first, second));
        String id = String.valueOf(((List<Map<String, Object>>) service
                .listAdminMessages(FirebaseService.AdminMessageKind.NOTICE).get("items")).getFirst().get("id"));
        // 같은 시각에 생긴 다른 알림(제보 처리, 내용이 다른 공지)은 지우면 안 됩니다.
        QueryDocumentSnapshot sameTimeReport = doc("r1", Map.of("userId", "u1", "type", "REPORT_APPROVED",
                "title", "점검 안내", "body", "내일 점검합니다.", "createdAt", NOTICE_AT));
        QueryDocumentSnapshot otherNotice = doc("n9", notice("u3", "다른 공지", "내용", NOTICE_AT, false));
        stubSameTime(List.of(first, second, sameTimeReport, otherNotice));
        WriteBatch batch = mock(WriteBatch.class);
        when(db.batch()).thenReturn(batch);
        when(batch.commit()).thenReturn(ApiFutures.immediateFuture(List.of()));

        Map<String, Object> result = service.recallAdminMessage(FirebaseService.AdminMessageKind.NOTICE, id);

        assertThat(result).containsEntry("deleted", 2).containsEntry("id", id);
        verify(batch).delete(first.getReference());
        verify(batch).delete(second.getReference());
        verify(batch, never()).delete(sameTimeReport.getReference());
        verify(batch, never()).delete(otherNotice.getReference());
        verify(batch).commit();
    }

    @Test
    @SuppressWarnings("unchecked")
    void theGeneralNotificationScreenCannotRecallANoticeAndUnknownIdsAreRejected() throws Exception {
        QueryDocumentSnapshot first = doc("n1", notice("u1", "점검 안내", "내일 점검합니다.", NOTICE_AT, false));
        stubNoticeScan(List.of(first));
        String id = String.valueOf(((List<Map<String, Object>>) service
                .listAdminMessages(FirebaseService.AdminMessageKind.NOTICE).get("items")).getFirst().get("id"));
        stubSameTime(List.of(first));

        assertThatThrownBy(() -> service.recallAdminMessage(FirebaseService.AdminMessageKind.GENERAL, id))
                .isInstanceOf(NoSuchElementException.class);
        assertThatThrownBy(() -> service.recallAdminMessage(FirebaseService.AdminMessageKind.NOTICE,
                NOTICE_AT + "~0000000000000000")).isInstanceOf(NoSuchElementException.class);
        assertThatThrownBy(() -> service.recallAdminMessage(FirebaseService.AdminMessageKind.NOTICE, "../notice"))
                .isInstanceOf(IllegalArgumentException.class);
        verify(db, never()).batch();
    }

    private void stubNoticeScan(List<QueryDocumentSnapshot> documents) {
        Query byType = mock(Query.class);
        Query limited = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(notifications.whereIn("type", List.<Object>of("notice", "admin"))).thenReturn(byType);
        when(byType.limit(5000)).thenReturn(limited);
        when(limited.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.getDocuments()).thenReturn(documents);
    }

    private void stubSameTime(List<QueryDocumentSnapshot> documents) {
        Query sameTime = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(notifications.whereEqualTo("createdAt", NOTICE_AT)).thenReturn(sameTime);
        when(sameTime.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.getDocuments()).thenReturn(documents);
    }

    private void stubUser(String uid, Map<String, Object> data) {
        DocumentReference reference = mock(DocumentReference.class);
        DocumentSnapshot snapshot = mock(DocumentSnapshot.class);
        when(users.document(uid)).thenReturn(reference);
        when(reference.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.exists()).thenReturn(true);
        when(snapshot.getData()).thenReturn(new HashMap<>(data));
    }

    private static Map<String, Object> notice(String uid, String title, String body, String createdAt, boolean read) {
        return Map.of("userId", uid, "type", "notice", "title", title, "body", body,
                "createdAt", createdAt, "isRead", read);
    }

    private static Map<String, Object> legacy(String uid, String title, String body, String createdAt) {
        return Map.of("userId", uid, "type", "admin", "title", title, "body", body,
                "createdAt", createdAt, "isRead", false);
    }

    private static QueryDocumentSnapshot doc(String id, Map<String, Object> data) {
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        DocumentReference reference = mock(DocumentReference.class);
        when(document.getId()).thenReturn(id);
        when(document.getData()).thenReturn(new HashMap<>(data));
        when(document.getReference()).thenReturn(reference);
        return document;
    }
}
