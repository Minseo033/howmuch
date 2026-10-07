package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.google.cloud.firestore.WriteResult;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * P3 정리: BE-CORE-26(가격 이력 날짜=승인일), WEB-ADM-18(가입일 없는 회원도 목록에 포함),
 * QA 2026-10-07 #48(댓글의 게시글·작성자 표시)·#57(함께 지운 답글 ID).
 */
class FirebaseServiceAdminListsAndHistoryTest {
    @Test
    void priceHistoryIsDatedByApprovalNotBySubmission() throws Exception {
        FirebaseService service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(service, "cachedStores", List.of(Map.of("storeId", "store_a", "storeName", "국밥집",
                "address", "서울 중구", "menu1", "국밥", "price1", "6500")));
        Map<String, Object> approved = new HashMap<>(Map.of("id", "report-1", "storeId", "store_a", "storeName", "국밥집",
                "status", "APPROVED", "resolution", "PRICE", "changeType", "rise",
                "appliedFields", Map.of("menu1", "국밥", "price1", "6500", "free1", false),
                "createdAt", "2026-09-01T00:00:00Z", "processedAt", "2026-09-05T03:00:00Z"));
        Map<String, Object> legacy = new HashMap<>(Map.of("id", "report-0", "storeId", "store_a", "storeName", "국밥집",
                "status", "APPROVED", "changeType", "drop", "menu1", "국밥", "price1", "6000",
                "createdAt", "2026-08-01T00:00:00Z"));
        ReflectionTestUtils.setField(service, "cachedUserStores", List.of(approved, legacy));

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> history = (List<Map<String, Object>>) service.getPriceHistory("store_a", "국밥").get("history");

        assertThat(history).extracting(item -> item.get("date"))
                .containsExactly("2026-09-05T03:00:00Z", "2026-08-01T00:00:00Z");
        assertThat(history.getFirst()).containsEntry("reportedAt", "2026-09-01T00:00:00Z");
    }

    @Test
    void membersWithoutASignupDateStillAppearAfterDatedMembers() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference users = mock(CollectionReference.class);
        Query limited = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(db.collection("users")).thenReturn(users);
        when(users.limit(5000)).thenReturn(limited);
        when(limited.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        List<QueryDocumentSnapshot> documents = List.of(
                user("old", Map.of("nickname", "옛회원", "createdAt", "2026-01-01T00:00:00Z")),
                user("goal-only", Map.of("savingsGoalAmount", 50000)),
                user("new", Map.of("nickname", "새회원", "createdAt", "2026-10-01T00:00:00Z", "secret", "x")));
        when(snapshot.getDocuments()).thenReturn(documents);
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

        List<Map<String, Object>> result = service.getAllUsers();

        assertThat(result).extracting(item -> item.get("id")).containsExactly("new", "old", "goal-only");
        assertThat(result.getFirst()).doesNotContainKey("secret");
    }

    @Test
    void adminCommentsCarryTheirPostAndAuthorNicknameInsteadOfRawIds() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference comments = mock(CollectionReference.class);
        Query ordered = mock(Query.class);
        Query limited = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(db.collection("comments")).thenReturn(comments);
        when(comments.orderBy("createdAt", Query.Direction.DESCENDING)).thenReturn(ordered);
        when(ordered.limit(anyInt())).thenReturn(limited);
        when(limited.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        List<QueryDocumentSnapshot> documents = List.of(
                user("c2", Map.of("postId", "post-1", "userId", "u1", "content", "답글", "parentId", "c1")),
                user("c1", Map.of("postId", "post-1", "userId", "u1", "content", "댓글")),
                user("c3", Map.of("postId", "gone", "userId", "u2", "content", "지워진 글의 댓글")));
        when(snapshot.getDocuments()).thenReturn(documents);
        CollectionReference users = mock(CollectionReference.class);
        when(db.collection("users")).thenReturn(users);
        DocumentReference member = existing(users, "u1", Map.of("nickname", "기미서"));
        missing(users, "u2");
        CollectionReference reports = mock(CollectionReference.class);
        when(db.collection("stores_user")).thenReturn(reports);
        missing(reports, "gone");
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(service, "cachedUserStores", List.of(Map.of("id", "post-1",
                "storeName", "노랑통닭", "menu1", "알싸한 마늘 치킨", "price1", "24000")));

        List<Map<String, Object>> result = service.getAllComments();

        assertThat(result.get(0)).containsEntry("authorName", "기미서").containsEntry("postStoreName", "노랑통닭")
                .containsEntry("postMenu", "알싸한 마늘 치킨").containsEntry("postPrice", "24000")
                .containsEntry("userId", "u1").containsEntry("postId", "post-1")
                .containsEntry("parentId", "c1").containsEntry("isReply", true);
        assertThat(result.get(1)).containsEntry("authorName", "기미서").containsEntry("isReply", false);
        assertThat(result.get(2)).containsEntry("authorName", "회원 정보 없음").containsEntry("postId", "gone")
                .doesNotContainKey("postStoreName");
        verify(member, times(1)).get();
        verify(reports, never()).document("post-1");
    }

    @Test
    void deletingACommentReturnsTheRepliesDeletedWithIt() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference comments = mock(CollectionReference.class);
        when(db.collection("comments")).thenReturn(comments);
        DocumentReference parent = existing(comments, "c1", Map.of("postId", "post-1", "content", "댓글"));
        when(parent.delete()).thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));
        Query replies = mock(Query.class);
        QuerySnapshot replySnapshot = mock(QuerySnapshot.class);
        when(comments.whereEqualTo("parentId", "c1")).thenReturn(replies);
        when(replies.get()).thenReturn(ApiFutures.immediateFuture(replySnapshot));
        List<QueryDocumentSnapshot> replyDocuments = List.of(reply("r1"), reply("r2"));
        when(replySnapshot.getDocuments()).thenReturn(replyDocuments);
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

        assertThat(service.deleteComment("c1")).containsExactly("c1", "r1", "r2");
        verify(parent).delete();
    }

    private DocumentReference existing(CollectionReference collection, String id, Map<String, Object> data) {
        DocumentReference reference = mock(DocumentReference.class);
        DocumentSnapshot snapshot = mock(DocumentSnapshot.class);
        when(collection.document(id)).thenReturn(reference);
        when(reference.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.exists()).thenReturn(true);
        when(snapshot.getData()).thenReturn(new HashMap<>(data));
        return reference;
    }

    private void missing(CollectionReference collection, String id) {
        DocumentReference reference = mock(DocumentReference.class);
        DocumentSnapshot snapshot = mock(DocumentSnapshot.class);
        when(collection.document(id)).thenReturn(reference);
        when(reference.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.exists()).thenReturn(false);
    }

    private QueryDocumentSnapshot reply(String id) {
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        DocumentReference reference = mock(DocumentReference.class);
        when(document.getId()).thenReturn(id);
        when(document.getReference()).thenReturn(reference);
        when(reference.delete()).thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));
        return document;
    }

    private QueryDocumentSnapshot user(String id, Map<String, Object> data) {
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        when(document.getId()).thenReturn(id);
        when(document.getData()).thenReturn(data);
        return document;
    }
}
