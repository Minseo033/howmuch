package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.*;
import com.howmuch.dto.PriceAlertBatchRequest;
import org.junit.jupiter.api.Test;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class FirebaseServicePriceAlertBatchTest {
    private final Firestore db = mock(Firestore.class);
    private final WriteBatch batch = mock(WriteBatch.class);
    private final DocumentReference settings = mock(DocumentReference.class);
    private final FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

    private void prepareBatch() {
        var collection = mock(CollectionReference.class);
        when(db.collection("notification_settings")).thenReturn(collection);
        when(collection.document("user-1")).thenReturn(settings);
        when(db.batch()).thenReturn(batch);
        when(batch.commit()).thenReturn(ApiFutures.immediateFuture(List.of()));
    }
    private DocumentReference ownStore() {
        var collection = mock(CollectionReference.class);
        var query = mock(Query.class);
        var snapshot = mock(QuerySnapshot.class);
        var document = mock(QueryDocumentSnapshot.class);
        var reference = mock(DocumentReference.class);
        when(db.collection("favorites")).thenReturn(collection);
        when(collection.whereEqualTo("userId", "user-1")).thenReturn(query);
        when(query.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.getDocuments()).thenReturn(List.of(document));
        when(document.getData()).thenReturn(Map.of("storeId", "store_1", "userId", "user-1"));
        when(document.getReference()).thenReturn(reference);
        return reference;
    }
    private PriceAlertBatchRequest request(String... ids) {
        var request = new PriceAlertBatchRequest();
        request.setStores(java.util.Arrays.stream(ids).map(id -> {
            var preference = new PriceAlertBatchRequest.StorePreference();
            preference.setStoreId(id); preference.setEnabled(false); return preference;
        }).toList());
        request.setNotifyOnDrop(true); request.setNotifyOnRise(false); request.setNotifyOnNewMenu(true);
        return request;
    }
    @Test void commitsOwnedStoreAndConditionsTogether() throws Exception {
        prepareBatch(); var reference = ownStore();
        service.savePriceAlertSettings("user-1", request("store_1"));
        verify(batch).update(reference, "priceAlertEnabled", false);
        verify(batch).set(eq(settings), argThat((Map<String, Object> data) ->
                data.get("notifyOnDrop").equals(true) && !data.containsKey("price") && !data.containsKey("all")), any(SetOptions.class));
        verify(batch).commit();
        verify(reference, never()).update(anyString(), any());
    }
    @Test void persistsConditionsEvenWithoutFavorites() throws Exception {
        prepareBatch();
        service.savePriceAlertSettings("user-1", request());
        verify(batch).commit();
        verify(db, never()).collection("favorites");
    }
    @Test void unknownOrAnotherUsersStoreCannotCausePartialWrites() {
        ownStore();
        assertThatThrownBy(() -> service.savePriceAlertSettings("user-1", request("store_1", "store_other")))
                .isInstanceOf(NoSuchElementException.class);
        verify(db, never()).batch();
    }
    @Test void duplicateIdsAreRejectedBeforeWriting() {
        ownStore();
        assertThatThrownBy(() -> service.savePriceAlertSettings("user-1", request("store_1", "store_1")))
                .isInstanceOf(IllegalArgumentException.class);
        verify(db, never()).batch();
    }
    @Test void failedCommitPropagatesInsteadOfReportingSuccess() {
        prepareBatch(); ownStore();
        when(batch.commit()).thenReturn(ApiFutures.immediateFailedFuture(new IllegalStateException("write failed")));
        assertThatThrownBy(() -> service.savePriceAlertSettings("user-1", request("store_1"))).hasCauseInstanceOf(IllegalStateException.class);
    }
}
