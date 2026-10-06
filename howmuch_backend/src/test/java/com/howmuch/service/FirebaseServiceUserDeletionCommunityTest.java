package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.AggregateQuery;
import com.google.cloud.firestore.AggregateQuerySnapshot;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.google.cloud.firestore.WriteResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** BE-CORE-3·WEB-ADM-9·BE-CORE-11·BE-CORE-12: 탈퇴 후 커뮤니티 카운터·고아 답글·관련 알림·캐시 정합성 */
class FirebaseServiceUserDeletionCommunityTest {
    private static final String UID = "gone";
    private final Firestore db = mock(Firestore.class);
    private final ReportImageStorage imageStorage = mock(ReportImageStorage.class);
    private final FirebaseService service = new FirebaseService(db, imageStorage);
    private final Map<String, CollectionReference> collections = new HashMap<>();
    private DocumentReference otherParentRef;
    private DocumentReference orphanReplyRef;
    private DocumentReference staleNotificationRef;

    @BeforeEach
    void setUp() throws Exception {
        for (String name : List.of("reviews", "stores_user", "visits", "receipt_verifications", "favorites",
                "inquiries", "comments", "feed_likes", "feed_notifications", "notifications", "device_tokens",
                "notification_settings", "users")) {
            CollectionReference collection = mock(CollectionReference.class);
            when(db.collection(name)).thenReturn(collection);
            collections.put(name, collection);
        }
        for (String name : List.of("reviews")) query(name, "authorUid", UID, List.of());
        for (String name : List.of("visits", "receipt_verifications", "favorites", "inquiries",
                "feed_notifications", "notifications", "device_tokens")) {
            query(name, "userId", UID, List.of());
        }
        // 본인 미승인 제보는 글째 지워지므로 카운터를 다시 셀 필요가 없습니다.
        QueryDocumentSnapshot ownPost = doc("post-own", Map.of("reporterId", UID, "status", "PENDING"));
        when(ownPost.getString("status")).thenReturn("PENDING");
        query("stores_user", "reporterId", UID, List.of(ownPost));
        for (String[] relation : new String[][]{{"comments", "postId"}, {"feed_likes", "postId"},
                {"feed_notifications", "postId"}, {"notifications", "relatedReportId"}, {"notifications", "relatedPostId"}}) {
            query(relation[0], relation[1], "post-own", List.of());
        }

        QueryDocumentSnapshot ownComment = doc("c-own", Map.of("userId", UID, "postId", "post-other"));
        QueryDocumentSnapshot ownReply = doc("r-own", Map.of("userId", UID, "postId", "post-other", "parentId", "c-own"));
        QueryDocumentSnapshot replyOnOther = doc("r-on-other",
                Map.of("userId", UID, "postId", "post-other2", "parentId", "c-other"));
        QueryDocumentSnapshot orphanReply = doc("r-other",
                Map.of("userId", "user-2", "postId", "post-other", "parentId", "c-own"));
        orphanReplyRef = orphanReply.getReference();
        query("comments", "userId", UID, List.of(ownComment, ownReply, replyOnOther));
        query("comments", "parentId", "c-own", List.of(orphanReply, ownReply));
        Query otherParentReplies = query("comments", "parentId", "c-other", List.of());
        AggregateQuery count = mock(AggregateQuery.class);
        AggregateQuerySnapshot countSnapshot = mock(AggregateQuerySnapshot.class);
        when(otherParentReplies.count()).thenReturn(count);
        when(count.get()).thenReturn(ApiFutures.immediateFuture(countSnapshot));
        when(countSnapshot.getCount()).thenReturn(2L);
        otherParentRef = mock(DocumentReference.class);
        when(collections.get("comments").document("c-other")).thenReturn(otherParentRef);
        when(otherParentRef.update("replyCount", 2L)).thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));

        QueryDocumentSnapshot like = doc("like-1", Map.of("userId", UID, "postId", "post-liked"));
        query("feed_likes", "userId", UID, List.of(like));

        QueryDocumentSnapshot staleNotification = doc("n-1", Map.of("userId", "user-3", "relatedCommentId", "c-own"));
        staleNotificationRef = staleNotification.getReference();
        Query byComment = mock(Query.class);
        QuerySnapshot byCommentSnapshot = mock(QuerySnapshot.class);
        when(collections.get("notifications").whereIn(eq("relatedCommentId"), anyList())).thenReturn(byComment);
        when(byComment.get()).thenReturn(ApiFutures.immediateFuture(byCommentSnapshot));
        List<QueryDocumentSnapshot> stale = List.of(staleNotification);
        when(byCommentSnapshot.getDocuments()).thenReturn(stale);

        DocumentReference settings = mock(DocumentReference.class);
        DocumentReference user = mock(DocumentReference.class);
        when(collections.get("notification_settings").document(UID)).thenReturn(settings);
        when(collections.get("users").document(UID)).thenReturn(user);
        when(settings.delete()).thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));
        when(user.delete()).thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));
    }

    @Test
    void withdrawalRecountsOtherPostsRemovesOrphanRepliesAndTheirNotifications() throws Exception {
        Map<String, Object> result = service.deleteUser(UID);

        assertThat(result).containsEntry("comments", 3).containsEntry("orphanReplies", 1)
                .containsEntry("feedLikes", 1).containsEntry("reports", 1);
        verify(orphanReplyRef).delete();
        verify(otherParentRef).update("replyCount", 2L);
        verify(staleNotificationRef).delete();
        // 다른 사람 글의 댓글·좋아요 수를 다시 셉니다. 지워진 본인 글은 다시 세지 않습니다.
        CollectionReference comments = collections.get("comments");
        verify(comments).whereEqualTo("postId", "post-other");
        verify(comments).whereEqualTo("postId", "post-other2");
        verify(comments).whereEqualTo("postId", "post-liked");
        verify(collections.get("stores_user"), never()).document("post-own");
    }

    @Test
    void cacheReplacementKeepsReportsAddedDuringWithdrawal() throws Exception {
        ReflectionTestUtils.setField(service, "cachedUserStores", List.of(
                Map.of("id", "post-own", "reporterId", UID, "status", "PENDING"),
                Map.of("id", "approved", "reporterId", UID, "status", "APPROVED"),
                Map.of("id", "someone-else", "reporterId", "user-2", "status", "PENDING")));

        service.deleteUser(UID);

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> cache = (List<Map<String, Object>>) ReflectionTestUtils.getField(service, "cachedUserStores");
        assertThat(cache).extracting(item -> item.get("id")).containsExactly("approved", "someone-else");
        assertThat(cache.getFirst()).containsEntry("reporterId", "");
    }

    private Query query(String collection, String field, Object value, List<QueryDocumentSnapshot> documents) {
        Query query = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(collections.get(collection).whereEqualTo(field, value)).thenReturn(query);
        when(query.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.getDocuments()).thenReturn(documents);
        return query;
    }

    private QueryDocumentSnapshot doc(String id, Map<String, Object> data) {
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        DocumentReference reference = mock(DocumentReference.class);
        when(document.getId()).thenReturn(id);
        when(document.getData()).thenReturn(data);
        data.forEach((key, value) -> when(document.get(key)).thenReturn(value));
        when(document.getReference()).thenReturn(reference);
        when(reference.delete()).thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));
        return document;
    }
}

