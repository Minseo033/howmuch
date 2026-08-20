package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.WriteResult;
import com.google.api.core.ApiFuture;
import com.howmuch.dto.StoreDto;
import org.junit.jupiter.api.Test;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.concurrent.ExecutionException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class PublicDataServiceTest {

    @Test
    void refusesToStartWithoutAServerSideApiKey() {
        PublicDataService service = new PublicDataService(
                WebClient.builder(),
                mock(GeocodingService.class),
                mock(Firestore.class),
                "");

        assertThatThrownBy(service::syncAllPublicDataInBackground)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("PUBLIC_DATA_API_KEY");
    }

    @Test
    void reportsSuccessfulFirestoreWrites() throws Exception {
        Firestore firestore = mock(Firestore.class);
        CollectionReference collection = mock(CollectionReference.class);
        DocumentReference document = mock(DocumentReference.class);
        @SuppressWarnings("unchecked")
        ApiFuture<WriteResult> future = mock(ApiFuture.class);
        when(firestore.collection("stores")).thenReturn(collection);
        when(collection.document("Store_Seoul_Jongno")).thenReturn(document);
        when(document.set(org.mockito.ArgumentMatchers.any(StoreDto.class))).thenReturn(future);

        PublicDataService service = serviceWith(firestore);

        assertThat(service.saveToFirestore(store()).block()).isTrue();
    }

    @Test
    void reportsFailedFirestoreWritesWithoutCountingThemAsSaved() throws Exception {
        Firestore firestore = mock(Firestore.class);
        CollectionReference collection = mock(CollectionReference.class);
        DocumentReference document = mock(DocumentReference.class);
        @SuppressWarnings("unchecked")
        ApiFuture<WriteResult> future = mock(ApiFuture.class);
        when(firestore.collection("stores")).thenReturn(collection);
        when(collection.document("Store_Seoul_Jongno")).thenReturn(document);
        when(document.set(org.mockito.ArgumentMatchers.any(StoreDto.class))).thenReturn(future);
        when(future.get()).thenThrow(new ExecutionException(new RuntimeException("write failed")));

        PublicDataService service = serviceWith(firestore);

        assertThat(service.saveToFirestore(store()).block()).isFalse();
    }

    private PublicDataService serviceWith(Firestore firestore) {
        return new PublicDataService(
                WebClient.builder(),
                mock(GeocodingService.class),
                firestore,
                "test-key");
    }

    private StoreDto store() {
        return StoreDto.builder()
                .storeName("Store")
                .cityProvince("Seoul")
                .cityDistrict("Jongno")
                .build();
    }
}
