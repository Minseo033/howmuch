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

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FirebaseServiceNotificationTest {

    @Test
    void returnsOnlyTheLatestHundredNotifications() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference notifications = mock(CollectionReference.class);
        Query userQuery = mock(Query.class);
        Query orderedQuery = mock(Query.class);
        Query limitedQuery = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(db.collection("notifications")).thenReturn(notifications);
        when(notifications.whereEqualTo("userId", "user-1")).thenReturn(userQuery);
        when(userQuery.orderBy("createdAt", Query.Direction.DESCENDING)).thenReturn(orderedQuery);
        when(orderedQuery.limit(100)).thenReturn(limitedQuery);
        when(limitedQuery.get()).thenReturn(ApiFutures.immediateFuture(snapshot));

        List<QueryDocumentSnapshot> documents = new ArrayList<>();
        for (int index = 0; index < 105; index++) {
            QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
            when(document.getId()).thenReturn("notification-" + index);
            when(document.getData()).thenReturn(Map.of(
                    "title", "알림 " + index,
                    "body", "내용",
                    "type", "ADMIN",
                    "isRead", false,
                    "createdAt", java.time.Instant.ofEpochSecond(index).toString()));
            documents.add(document);
        }
        when(snapshot.getDocuments()).thenReturn(documents);
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

        var result = service.getNotifications("user-1");

        assertThat(result).hasSize(100);
        assertThat(result.getFirst().getId()).isEqualTo("notification-104");
        assertThat(result.getLast().getId()).isEqualTo("notification-5");
        verify(orderedQuery).limit(100);
    }

    @Test
    void refusesToCreateAnAdminNotificationForANonexistentUser() {
        Firestore db = mock(Firestore.class);
        CollectionReference users = mock(CollectionReference.class);
        DocumentReference userReference = mock(DocumentReference.class);
        DocumentSnapshot userSnapshot = mock(DocumentSnapshot.class);
        when(db.collection("users")).thenReturn(users);
        when(users.document("missing-user")).thenReturn(userReference);
        when(userReference.get()).thenReturn(ApiFutures.immediateFuture(userSnapshot));
        when(userSnapshot.exists()).thenReturn(false);
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

        assertThatThrownBy(() -> service.sendAdminNotification(
                " missing-user ", "알림", "내용", "admin"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("대상 회원을 찾을 수 없습니다.");
    }
}
