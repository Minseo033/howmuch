package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FirebaseServiceCommunityQueryTest {

    @Test
    void limitsTopLevelCommentsAndCachesRepeatedAuthors() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference comments = mock(CollectionReference.class);
        Query postQuery = mock(Query.class);
        Query parentQuery = mock(Query.class);
        Query orderedQuery = mock(Query.class);
        Query limitedQuery = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);

        when(db.collection("comments")).thenReturn(comments);
        when(comments.whereEqualTo("postId", "post-1")).thenReturn(postQuery);
        when(postQuery.whereEqualTo("parentId", null)).thenReturn(parentQuery);
        when(parentQuery.orderBy("createdAt", Query.Direction.ASCENDING)).thenReturn(orderedQuery);
        when(orderedQuery.limit(200)).thenReturn(limitedQuery);
        when(limitedQuery.get()).thenReturn(ApiFutures.immediateFuture(snapshot));

        QueryDocumentSnapshot first = comment("comment-1", "author-1", "2026-09-01T00:00:00Z");
        QueryDocumentSnapshot second = comment("comment-2", "author-1", "2026-09-01T00:01:00Z");
        when(snapshot.getDocuments()).thenReturn(List.of(first, second));

        CollectionReference users = mock(CollectionReference.class);
        DocumentReference userReference = mock(DocumentReference.class);
        DocumentSnapshot userSnapshot = mock(DocumentSnapshot.class);
        when(db.collection("users")).thenReturn(users);
        when(users.document("author-1")).thenReturn(userReference);
        when(userReference.get()).thenReturn(ApiFutures.immediateFuture(userSnapshot));
        when(userSnapshot.exists()).thenReturn(true);
        when(userSnapshot.getData()).thenReturn(Map.of("nickname", "동네이웃"));

        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));
        var result = service.getComments("post-1", "viewer-1");

        assertThat(result).hasSize(2);
        assertThat(result).extracting("author").containsOnly("동네이웃");
        verify(orderedQuery).limit(200);
        verify(userReference).get();
    }

    @Test
    void limitsRepliesBeforeReadingDocuments() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference comments = mock(CollectionReference.class);
        Query parentQuery = mock(Query.class);
        Query orderedQuery = mock(Query.class);
        Query limitedQuery = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);

        when(db.collection("comments")).thenReturn(comments);
        when(comments.whereEqualTo("parentId", "comment-1")).thenReturn(parentQuery);
        when(parentQuery.orderBy("createdAt", Query.Direction.ASCENDING)).thenReturn(orderedQuery);
        when(orderedQuery.limit(100)).thenReturn(limitedQuery);
        when(limitedQuery.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.getDocuments()).thenReturn(List.of());

        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));
        assertThat(service.getReplies("comment-1", "viewer-1")).isEmpty();
        verify(orderedQuery).limit(100);
    }

    private QueryDocumentSnapshot comment(String id, String userId, String createdAt) {
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        when(document.getId()).thenReturn(id);
        when(document.getData()).thenReturn(Map.of(
                "userId", userId,
                "content", "내용",
                "createdAt", createdAt,
                "replyCount", 0));
        return document;
    }
}
