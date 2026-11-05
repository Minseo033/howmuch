package com.howmuch.service;

import com.google.api.core.ApiFuture;
import com.google.api.core.ApiFutures;
import com.google.api.gax.rpc.AlreadyExistsException;
import com.google.api.gax.rpc.StatusCode;
import com.google.cloud.firestore.*;
import com.howmuch.dto.CommentResponse;
import com.howmuch.dto.VisitLocationEvidence;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.*;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class FirebaseServicePostCommitCancellationTest {
    @AfterEach void clearInterrupt() { Thread.interrupted(); }

    @Test
    @SuppressWarnings("unchecked")
    void committedResubmissionIsAcceptedAndKeepsNewImagesWhenOldArchiveCleanupIsInterrupted() throws Exception {
        Firestore db = mock(Firestore.class);
        ReportImageStorage images = mock(ReportImageStorage.class);
        CollectionReference receipts = mock(CollectionReference.class);
        CollectionReference visits = mock(CollectionReference.class);
        DocumentReference receipt = mock(DocumentReference.class);
        DocumentReference archive = mock(DocumentReference.class);
        DocumentReference visit = mock(DocumentReference.class);
        DocumentSnapshot old = mock(DocumentSnapshot.class);
        Transaction transaction = mock(Transaction.class);
        String fingerprint = "a".repeat(64);
        String id = "receipt_" + fingerprint;
        when(db.collection("receipt_verifications")).thenReturn(receipts);
        when(db.collection("visits")).thenReturn(visits);
        when(visits.document(anyString())).thenReturn(visit);
        when(visit.get()).thenReturn(ApiFutures.immediateFuture(mock(DocumentSnapshot.class)));
        when(receipts.document(id)).thenReturn(receipt);
        when(receipts.document(id + "_rejected_1")).thenReturn(archive);
        when(receipt.getId()).thenReturn(id);
        when(receipt.create(anyMap())).thenReturn(ApiFutures.immediateFailedFuture(
                new AlreadyExistsException(new RuntimeException("exists"), mock(StatusCode.class), false)));
        when(transaction.get(receipt)).thenReturn(ApiFutures.immediateFuture(old));
        when(old.exists()).thenReturn(true);
        when(old.getString("status")).thenReturn("REJECTED");
        when(old.getString("userId")).thenReturn("user");
        when(old.get("imageUrls")).thenReturn(List.of("old-image"));
        when(old.getData()).thenReturn(Map.of("status", "REJECTED", "imageUrls", List.of("old-image")));
        Map<DocumentReference, Map<String, Object>> committed = new HashMap<>();
        when(transaction.set(any(DocumentReference.class), anyMap())).thenAnswer(call -> {
            Map<String, Object> written = call.getArgument(1);
            committed.put(call.getArgument(0), new HashMap<>(written));
            return transaction;
        });
        when(db.runTransaction(any())).thenAnswer(call -> {
            Transaction.Function<Object> callback = call.getArgument(0);
            return ApiFutures.immediateFuture(callback.updateCallback(transaction));
        });
        when(images.deleteOwned(eq("user"), anyCollection())).thenThrow(new InterruptedException("old cleanup cancelled"));
        FirebaseService service = new FirebaseService(db, images);

        String accepted = service.saveReceiptVerification("user", "store", "Store", "Menu", 6000L,
                fingerprint, List.of("new-image"), null, new VisitLocationEvidence(10d, 5d));

        assertThat(accepted).isEqualTo(id);
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        assertThat(committed.get(receipt)).containsEntry("status", "PENDING")
                .containsEntry("imageUrls", List.of("new-image")).containsEntry("submissionVersion", 2L);
        assertThat(committed.get(archive)).containsEntry("imageCleanupStatus", "PENDING")
                .containsEntry("imageUrls", List.of("old-image"));
        verify(images).deleteOwned(eq("user"), argThat(urls -> urls.equals(Set.of("old-image"))));
        verify(images, never()).deleteOwned(eq("user"), argThat(urls -> urls.contains("new-image")));
        verify(archive, never()).update(anyMap());
        verify(receipt, never()).delete();
    }

    @ParameterizedTest
    @ValueSource(ints = {0, 1, 2})
    void committedCommentReturnsItsIdWhenCounterNotificationOrAuthorReadIsInterrupted(int phase) throws Exception {
        CommentFixture fixture = commentFixture(phase);

        CommentResponse accepted = fixture.service.createComment("post", "user", "accepted content");

        assertThat(accepted.getId()).isEqualTo("comment");
        assertThat(accepted.getContent()).isEqualTo("accepted content");
        assertThat(accepted.isMine()).isTrue();
        assertThat(accepted.getAuthor()).isNotBlank();
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        verify(fixture.comment).set(anyMap());
        verify(fixture.comment, never()).delete();
        if (phase == 0) verify(fixture.post, never()).get();
        if (phase < 2) verify(fixture.service, never()).getUserProfile(anyString());
    }

    @Test
    void committedReplyReturnsItsIdWhenCounterReadIsInterrupted() throws Exception {
        CommentFixture fixture = commentFixture(0);
        DocumentReference parent = mock(DocumentReference.class);
        DocumentSnapshot snapshot = mock(DocumentSnapshot.class);
        when(fixture.comments.document("parent")).thenReturn(parent);
        when(parent.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.exists()).thenReturn(true);
        when(snapshot.getData()).thenReturn(Map.of("postId", "post"));
        doReturn(true).when(fixture.service).feedExists("post");
        WriteBatch batch = mock(WriteBatch.class);
        when(fixture.db.batch()).thenReturn(batch);
        when(batch.commit()).thenReturn(ApiFutures.immediateFuture(List.of()));

        CommentResponse accepted = fixture.service.createReply("parent", "user", "reply accepted");

        assertThat(accepted.getId()).isEqualTo("comment");
        assertThat(accepted.getContent()).isEqualTo("reply accepted");
        assertThat(accepted.isMine()).isTrue();
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        verify(batch).commit();
        verify(fixture.post, never()).get();
        verify(fixture.comment, never()).delete();
    }

    @Test
    void precommitCommentInterruptionStillPropagatesAndDoesNotStartOptionalWork() throws Exception {
        CommentFixture fixture = commentFixture(0);
        @SuppressWarnings("unchecked") ApiFuture<WriteResult> write = mock(ApiFuture.class);
        when(fixture.comment.set(anyMap())).thenReturn(write);
        when(write.get()).thenThrow(new InterruptedException("primary write cancelled"));
        assertThatThrownBy(() -> fixture.service.createComment("post", "user", "not acknowledged"))
                .isInstanceOf(InterruptedException.class);
        verify(fixture.comments, never()).whereEqualTo(anyString(), any());
        verify(fixture.post, never()).get();
    }

    @Test
    void committedLikeDoesNotInventAReadbackCountWhenCounterReadIsInterrupted() throws Exception {
        CommentFixture fixture = commentFixture(0);
        DocumentReference like = mock(DocumentReference.class);
        when(fixture.likes.document(anyString())).thenReturn(like);
        when(like.set(anyMap())).thenReturn(ApiFutures.immediateFuture(null));

        Map<String, Object> accepted = fixture.service.likeFeed("post", "user");

        assertThat(accepted).containsEntry("likedByMe", true).containsEntry("countsPending", true)
                .doesNotContainKey("likes");
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        verify(like).set(anyMap());
    }

    @Test
    void legacyAdminNotificationCountsCommittedInboxWriteWhenPushIsInterrupted() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference users = mock(CollectionReference.class);
        CollectionReference notifications = mock(CollectionReference.class);
        DocumentReference user = mock(DocumentReference.class);
        DocumentReference notification = mock(DocumentReference.class);
        DocumentSnapshot existing = mock(DocumentSnapshot.class);
        when(db.collection("users")).thenReturn(users);
        when(db.collection("notifications")).thenReturn(notifications);
        when(users.document("user")).thenReturn(user);
        when(user.get()).thenReturn(ApiFutures.immediateFuture(existing));
        when(existing.exists()).thenReturn(true);
        when(notifications.document()).thenReturn(notification);
        when(notification.set(anyMap())).thenReturn(ApiFutures.immediateFuture(null));
        FirebaseService service = spy(new FirebaseService(db, mock(ReportImageStorage.class)));
        doThrow(new InterruptedException("push cancelled")).when(service).getNotificationSettings("user");

        assertThat(service.sendAdminNotification("user", "title", "body", "general", null))
                .containsEntry("sent", 1).containsEntry("skipped", 0).containsEntry("pending", 0);
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        verify(notification).set(anyMap());
        verify(db, never()).collection("device_tokens");
    }

    @Test
    void committedCommentDeletionReturnsDeletedIdWhenOptionalRecountIsCancelled() throws Exception {
        CommentFixture fixture = commentFixture(0);
        DocumentSnapshot snapshot = mock(DocumentSnapshot.class);
        when(fixture.comments.document("comment")).thenReturn(fixture.comment);
        when(fixture.comment.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.exists()).thenReturn(true);
        when(snapshot.getData()).thenReturn(Map.of("postId", "post", "parentId", "parent"));
        when(fixture.comment.delete()).thenReturn(ApiFutures.immediateFuture(null));
        when(fixture.comments.whereEqualTo("parentId", "parent"))
                .thenThrow(new java.util.concurrent.CancellationException("optional recount cancelled"));

        assertThat(fixture.service.deleteComment("comment")).containsExactly("comment");
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        verify(fixture.comment).delete();
        verify(fixture.db, never()).collection("notifications");
    }

    private record CommentFixture(Firestore db, FirebaseService service, CollectionReference comments,
                                  CollectionReference likes, DocumentReference comment, DocumentReference post) { }

    @SuppressWarnings("unchecked")
    private CommentFixture commentFixture(int phase) throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference comments = mock(CollectionReference.class);
        CollectionReference likes = mock(CollectionReference.class);
        CollectionReference reports = mock(CollectionReference.class);
        DocumentReference comment = mock(DocumentReference.class);
        DocumentReference post = mock(DocumentReference.class);
        when(db.collection("comments")).thenReturn(comments);
        when(db.collection("feed_likes")).thenReturn(likes);
        when(db.collection("stores_user")).thenReturn(reports);
        when(comments.document()).thenReturn(comment);
        when(comment.getId()).thenReturn("comment");
        when(comment.set(anyMap())).thenReturn(ApiFutures.immediateFuture(null));
        when(reports.document("post")).thenReturn(post);
        when(post.update(anyMap())).thenReturn(ApiFutures.immediateFuture(null));
        ApiFuture<DocumentSnapshot> postRead = mock(ApiFuture.class);
        when(post.get()).thenReturn(postRead);
        if (phase == 1) when(postRead.get()).thenThrow(new InterruptedException("notification cancelled"));
        else when(postRead.get()).thenReturn(mock(DocumentSnapshot.class));
        for (CollectionReference collection : List.of(comments, likes)) {
            Query query = mock(Query.class);
            AggregateQuery aggregate = mock(AggregateQuery.class);
            AggregateQuerySnapshot count = mock(AggregateQuerySnapshot.class);
            ApiFuture<AggregateQuerySnapshot> future = mock(ApiFuture.class);
            when(collection.whereEqualTo("postId", "post")).thenReturn(query);
            when(query.count()).thenReturn(aggregate);
            when(aggregate.get()).thenReturn(future);
            if (phase == 0 && collection == comments) when(future.get()).thenThrow(new InterruptedException("counter cancelled"));
            else when(future.get()).thenReturn(count);
        }
        FirebaseService service = spy(new FirebaseService(db, mock(ReportImageStorage.class)));
        doThrow(new InterruptedException("author cancelled")).when(service).getUserProfile("user");
        return new CommentFixture(db, service, comments, likes, comment, post);
    }
}
