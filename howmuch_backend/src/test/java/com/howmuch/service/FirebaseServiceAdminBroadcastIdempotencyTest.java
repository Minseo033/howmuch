package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.api.gax.rpc.AlreadyExistsException;
import com.google.api.gax.rpc.StatusCode;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.google.cloud.firestore.WriteResult;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** WEB-ADM-2·BE-CORE-23: 관리자 전체 발송은 requestId로 재요청 중복을 막습니다. */
class FirebaseServiceAdminBroadcastIdempotencyTest {
    @Test
    void retryingABroadcastWithTheSameRequestIdSkipsUsersWhoAlreadyReceivedIt() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference users = mock(CollectionReference.class);
        QuerySnapshot userSnapshot = mock(QuerySnapshot.class);
        when(db.collection("users")).thenReturn(users);
        when(users.get()).thenReturn(ApiFutures.immediateFuture(userSnapshot));
        List<QueryDocumentSnapshot> members = List.of(user("u1"), user("u2"), user("u3"));
        when(userSnapshot.getDocuments()).thenReturn(members);
        CollectionReference notifications = mock(CollectionReference.class);
        when(db.collection("notifications")).thenReturn(notifications);
        DocumentReference fresh = mock(DocumentReference.class);
        DocumentReference alreadySent = mock(DocumentReference.class);
        when(notifications.document(anyString())).thenReturn(fresh);
        when(notifications.document(expectedId("req-20261006-a", "u3"))).thenReturn(alreadySent);
        when(fresh.create(anyMap())).thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));
        when(alreadySent.create(anyMap())).thenReturn(ApiFutures.immediateFailedFuture(
                new AlreadyExistsException(new RuntimeException("exists"), mock(StatusCode.class), false)));
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

        Map<String, Object> result = service.publishAdminNotice("점검 안내", "내일 점검합니다.", "req-20261006-a");

        assertThat(result).containsEntry("sent", 2).containsEntry("skipped", 1)
                .containsEntry("broadcast", true).containsEntry("requestId", "req-20261006-a");
        verify(notifications).document(expectedId("req-20261006-a", "u1"));
        verify(notifications).document(expectedId("req-20261006-a", "u2"));
        verify(fresh, times(2)).create(anyMap());
        verify(notifications, never()).document();
    }

    @Test
    void malformedRequestIdsAreRejectedBeforeSending() {
        FirebaseService service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
        assertThatThrownBy(() -> service.publishAdminNotice("제목", "내용", "../bad"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThat(FirebaseService.isValidAdminRequestId("short")).isFalse();
        assertThat(FirebaseService.isValidAdminRequestId("req_2026-10-06_0001")).isTrue();
    }

    private static String expectedId(String requestId, String uid) throws Exception {
        byte[] hash = MessageDigest.getInstance("SHA-256").digest(uid.getBytes(StandardCharsets.UTF_8));
        return "admin_" + requestId + "_" + HexFormat.of().formatHex(hash).substring(0, 24);
    }

    private QueryDocumentSnapshot user(String uid) {
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        when(document.getId()).thenReturn(uid);
        return document;
    }
}

