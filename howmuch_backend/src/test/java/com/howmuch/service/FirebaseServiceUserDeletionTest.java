package com.howmuch.service;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QuerySnapshot;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.RETURNS_DEEP_STUBS;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class FirebaseServiceUserDeletionTest {

    @Test
    void removesPrivacyRelatedCollectionsAndEvictsTheUsersReportsFromCache() throws Exception {
        String uid = "user-1";
        Firestore firestore = mock(Firestore.class, RETURNS_DEEP_STUBS);
        ReportImageStorage imageStorage = mock(ReportImageStorage.class);
        FirebaseService service = new FirebaseService(firestore, imageStorage);

        stubEmptyQuery(firestore, "reviews", "authorUid", uid);
        stubEmptyQuery(firestore, "stores_user", "reporterId", uid);
        for (String collection : List.of(
                "visits",
                "receipt_verifications",
                "favorites",
                "inquiries",
                "comments",
                "feed_likes",
                "feed_notifications",
                "notifications",
                "device_tokens")) {
            stubEmptyQuery(firestore, collection, "userId", uid);
        }
        when(imageStorage.deleteAllOwned(uid)).thenReturn(2);
        ReflectionTestUtils.setField(service, "cachedUserStores", List.of(
                Map.of("id", "report-1", "reporterId", uid),
                Map.of("id", "report-2", "reporterId", "user-2")));

        Map<String, Object> result = service.deleteUser(uid);

        assertThat(result).containsEntry("uid", uid)
                .containsEntry("inquiries", 0)
                .containsEntry("receiptVerifications", 0)
                .containsEntry("comments", 0)
                .containsEntry("feedLikes", 0)
                .containsEntry("feedSubscriptions", 0)
                .containsEntry("notifications", 0)
                .containsEntry("deviceTokens", 0)
                .containsEntry("reportImages", 2);
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> cache = (List<Map<String, Object>>)
                ReflectionTestUtils.getField(service, "cachedUserStores");
        assertThat(cache).extracting(item -> item.get("id")).containsExactly("report-2");
    }

    private void stubEmptyQuery(
            Firestore firestore,
            String collection,
            String field,
            String value) throws Exception {
        CollectionReference collectionReference = mock(CollectionReference.class);
        Query query = mock(Query.class);
        @SuppressWarnings("unchecked")
        ApiFuture<QuerySnapshot> future = mock(ApiFuture.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(firestore.collection(collection)).thenReturn(collectionReference);
        when(collectionReference.whereEqualTo(field, value)).thenReturn(query);
        when(query.get()).thenReturn(future);
        when(future.get()).thenReturn(snapshot);
        when(snapshot.getDocuments()).thenReturn(List.of());
    }
}
