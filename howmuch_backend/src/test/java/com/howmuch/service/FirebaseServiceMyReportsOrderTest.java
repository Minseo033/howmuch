package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** 계약 C4: 내 제보 목록은 서버에서 createdAt 내림차순으로 정렬합니다. */
class FirebaseServiceMyReportsOrderTest {
    @Test
    void myReportsAreReturnedNewestFirstWithUndatedReportsLast() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference reports = mock(CollectionReference.class);
        Query query = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(db.collection("stores_user")).thenReturn(reports);
        when(reports.whereEqualTo("reporterId", "user-1")).thenReturn(query);
        when(query.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        List<QueryDocumentSnapshot> documents = List.of(
                report("middle", "2026-10-02T09:00:00Z"),
                report("undated", null),
                report("newest", "2026-10-05T09:00:00Z"),
                report("oldest", "2026-09-01T09:00:00Z"));
        when(snapshot.getDocuments()).thenReturn(documents);
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

        assertThat(service.getUserReports("user-1")).extracting(row -> row.get("id"))
                .containsExactly("newest", "middle", "oldest", "undated");
    }

    private QueryDocumentSnapshot report(String id, String createdAt) {
        Map<String, Object> data = new HashMap<>();
        data.put("storeName", id);
        data.put("reporterId", "user-1");
        if (createdAt != null) data.put("createdAt", createdAt);
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        when(document.getId()).thenReturn(id);
        when(document.getData()).thenReturn(data);
        return document;
    }
}
