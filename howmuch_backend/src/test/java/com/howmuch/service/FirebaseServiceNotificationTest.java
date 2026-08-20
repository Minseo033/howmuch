package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class FirebaseServiceNotificationTest {

    @Test
    void returnsOnlyTheLatestHundredNotifications() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference notifications = mock(CollectionReference.class);
        Query userQuery = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(db.collection("notifications")).thenReturn(notifications);
        when(notifications.whereEqualTo("userId", "user-1")).thenReturn(userQuery);
        when(userQuery.get()).thenReturn(ApiFutures.immediateFuture(snapshot));

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
    }
}
