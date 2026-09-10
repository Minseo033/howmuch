package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.google.cloud.firestore.SetOptions;
import com.google.cloud.firestore.WriteBatch;
import com.howmuch.dto.PriceAlertBatchRequest;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FirebaseServicePriceAlertBatchTest {
    private final Firestore db = mock(Firestore.class);
    private final WriteBatch batch = mock(WriteBatch.class);
    private final DocumentReference settings = mock(DocumentReference.class);
    private final FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

    private void prepareBatch() {
        CollectionReference collection = mock(CollectionReference.class);
        when(db.collection("notification_settings")).thenReturn(collection);
        when(collection.document("user-1")).thenReturn(settings);
        when(db.batch()).thenReturn(batch);
        when(batch.commit()).thenReturn(ApiFutures.immediateFuture(List.of()));
    }

    private DocumentReference ownStore() {
        CollectionReference collection = mock(CollectionReference.class);
        Query query = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        DocumentReference reference = mock(DocumentReference.class);
        when(db.collection("favorites")).thenReturn(collection);
        when(collection.whereEqualTo("userId", "user-1")).thenReturn(query);
        when(query.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.getDocuments()).thenReturn(List.of(document));
        when(document.getData()).thenReturn(Map.of("storeId", "store_1", "userId", "user-1"));
        when(document.getReference()).thenReturn(reference);
        return reference;
    }

    private PriceAlertBatchRequest request(String... ids) {
        PriceAlertBatchRequest request = new PriceAlertBatchRequest();
        request.setStores(Arrays.stream(ids).map(id -> {
            PriceAlertBatchRequest.StorePreference preference = new PriceAlertBatchRequest.StorePreference();
            preference.setStoreId(id);
            preference.setEnabled(false);
            return preference;
        }).toList());
        request.setNotifyOnDrop(true);
        request.setNotifyOnRise(false);
        request.setNotifyOnNewMenu(true);
        return request;
    }

    @Test
    void commitsOwnedStoreAndConditionsTogether() throws Exception {
        prepareBatch();
        DocumentReference reference = ownStore();

        service.savePriceAlertSettings("user-1", request("store_1"));

        verify(batch).update(reference, "priceAlertEnabled", false);
        verify(batch).set(eq(settings), argThat((Map<String, Object> data) ->
                data.get("notifyOnDrop").equals(true)
                        && !data.containsKey("price")
                        && !data.containsKey("all")), any(SetOptions.class));
        verify(batch).commit();
        verify(reference, never()).update(anyString(), any());
    }

    @Test
    void persistsConditionsEvenWithoutFavorites() throws Exception {
        prepareBatch();

        service.savePriceAlertSettings("user-1", request());

        verify(batch).commit();
        verify(db, never()).collection("favorites");
    }

    @Test
    void unknownOrAnotherUsersStoreCannotCausePartialWrites() {
        ownStore();

        assertThatThrownBy(() -> service.savePriceAlertSettings(
                "user-1", request("store_1", "store_other")))
                .isInstanceOf(NoSuchElementException.class);
        verify(db, never()).batch();
    }

    @Test
    void duplicateIdsAreRejectedBeforeWriting() {
        ownStore();

        assertThatThrownBy(() -> service.savePriceAlertSettings(
                "user-1", request("store_1", "store_1")))
                .isInstanceOf(IllegalArgumentException.class);
        verify(db, never()).batch();
    }

    @Test
    void failedCommitPropagatesInsteadOfReportingSuccess() {
        prepareBatch();
        ownStore();
        when(batch.commit()).thenReturn(
                ApiFutures.immediateFailedFuture(new IllegalStateException("write failed")));

        assertThatThrownBy(() -> service.savePriceAlertSettings("user-1", request("store_1")))
                .hasCauseInstanceOf(IllegalStateException.class);
    }
}
