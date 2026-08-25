package com.howmuch.service;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QuerySnapshot;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FirebaseServiceCommunityFeedTest {

    @Test
    void requestsTheNewestCommunityDocumentsBeforeApplyingTheLimit() throws Exception {
        Firestore firestore = mock(Firestore.class);
        ReportImageStorage imageStorage = mock(ReportImageStorage.class);
        CollectionReference collection = mock(CollectionReference.class);
        Query ordered = mock(Query.class);
        Query limited = mock(Query.class);
        @SuppressWarnings("unchecked")
        ApiFuture<QuerySnapshot> future = mock(ApiFuture.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(firestore.collection("stores_user")).thenReturn(collection);
        when(collection.orderBy("createdAt", Query.Direction.DESCENDING)).thenReturn(ordered);
        when(ordered.limit(25)).thenReturn(limited);
        when(limited.get()).thenReturn(future);
        when(future.get()).thenReturn(snapshot);
        when(snapshot.getDocuments()).thenReturn(List.of());
        FirebaseService service = new FirebaseService(firestore, imageStorage);
        ReflectionTestUtils.setField(service, "communityFeedMaxItems", 25);

        assertThat(service.getCommunityFeeds()).isEmpty();

        verify(collection).orderBy("createdAt", Query.Direction.DESCENDING);
        verify(ordered).limit(25);
    }
}
