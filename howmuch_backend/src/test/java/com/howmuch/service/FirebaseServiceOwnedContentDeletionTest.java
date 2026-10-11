package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.WriteResult;
import org.junit.jupiter.api.Test;

import java.util.NoSuchElementException;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.spy;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FirebaseServiceOwnedContentDeletionTest {

    @Test
    void deletesAReviewOwnedByTheAuthenticatedUser() throws Exception {
        Fixture fixture = new Fixture("reviews", "review-1", "authorUid", "user-1");

        fixture.service.deleteOwnedReview("review-1", "user-1");

        verify(fixture.document).delete();
    }

    @Test
    void neverDeletesAnotherUsersReview() {
        Fixture fixture = new Fixture("reviews", "review-1", "authorUid", "user-2");

        assertThatThrownBy(() -> fixture.service.deleteOwnedReview("review-1", "user-1"))
                .isInstanceOf(NoSuchElementException.class)
                .hasMessage("리뷰를 찾을 수 없습니다.");
        verify(fixture.document, never()).delete();
    }

    @Test
    void deletesAVisitOwnedByTheAuthenticatedUser() throws Exception {
        Fixture fixture = new Fixture("visits", "visit-1", "userId", "user-1");

        fixture.service.deleteOwnedVisit("visit-1", "user-1");

        verify(fixture.document).delete();
    }

    @Test
    void neverDeletesAnotherUsersVisit() {
        Fixture fixture = new Fixture("visits", "visit-1", "userId", "user-2");

        assertThatThrownBy(() -> fixture.service.deleteOwnedVisit("visit-1", "user-1"))
                .isInstanceOf(NoSuchElementException.class)
                .hasMessage("방문 기록을 찾을 수 없습니다.");
        verify(fixture.document, never()).delete();
    }

    @Test
    void deletesACommentOnlyAfterConfirmingItsOwner() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference comments = mock(CollectionReference.class);
        DocumentReference document = mock(DocumentReference.class);
        DocumentSnapshot snapshot = mock(DocumentSnapshot.class);
        when(db.collection("comments")).thenReturn(comments);
        when(comments.document("comment-1")).thenReturn(document);
        when(document.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.exists()).thenReturn(true);
        when(snapshot.getString("userId")).thenReturn("user-1");
        FirebaseService service = spy(new FirebaseService(db, mock(ReportImageStorage.class)));
        doReturn(java.util.List.of("comment-1")).when(service).deleteComment("comment-1");

        service.deleteOwnedComment("comment-1", "user-1");

        verify(service).deleteComment("comment-1");
    }

    @Test
    void neverDeletesAnotherUsersComment() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference comments = mock(CollectionReference.class);
        DocumentReference document = mock(DocumentReference.class);
        DocumentSnapshot snapshot = mock(DocumentSnapshot.class);
        when(db.collection("comments")).thenReturn(comments);
        when(comments.document("comment-1")).thenReturn(document);
        when(document.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.exists()).thenReturn(true);
        when(snapshot.getString("userId")).thenReturn("user-2");
        FirebaseService service = spy(new FirebaseService(db, mock(ReportImageStorage.class)));

        assertThatThrownBy(() -> service.deleteOwnedComment("comment-1", "user-1"))
                .isInstanceOf(NoSuchElementException.class)
                .hasMessage("댓글을 찾을 수 없습니다.");
        verify(service, never()).deleteComment("comment-1");
    }

    private static class Fixture {
        private final DocumentReference document = mock(DocumentReference.class);
        private final FirebaseService service;

        Fixture(String collectionName, String documentId, String ownerField, String ownerUid) {
            Firestore db = mock(Firestore.class);
            CollectionReference collection = mock(CollectionReference.class);
            DocumentSnapshot snapshot = mock(DocumentSnapshot.class);
            when(db.collection(collectionName)).thenReturn(collection);
            when(collection.document(documentId)).thenReturn(document);
            when(document.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
            when(snapshot.exists()).thenReturn(true);
            when(snapshot.getString(ownerField)).thenReturn(ownerUid);
            when(document.delete()).thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));
            service = new FirebaseService(db, mock(ReportImageStorage.class));
        }
    }
}
