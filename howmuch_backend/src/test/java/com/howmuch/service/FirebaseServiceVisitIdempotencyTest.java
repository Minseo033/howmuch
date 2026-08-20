package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import com.howmuch.dto.VisitRequest;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class FirebaseServiceVisitIdempotencyTest {

    private final FirebaseService service = new FirebaseService(
            mock(Firestore.class), mock(ReportImageStorage.class));

    @Test
    void sameUserStoreAndKoreanDateProducesTheSameVisitDocumentId() {
        VisitRequest request = VisitRequest.builder()
                .storeId("store-1")
                .storeName("테스트 식당")
                .build();

        String first = service.locationVisitDocumentId(
                "user-1", request, LocalDate.of(2026, 8, 19));
        String retry = service.locationVisitDocumentId(
                "user-1", request, LocalDate.of(2026, 8, 19));

        assertThat(first).isEqualTo(retry).startsWith("location_");
    }

    @Test
    void differentStoreOrDateProducesADifferentVisitDocumentId() {
        VisitRequest firstStore = VisitRequest.builder().storeId("store-1").build();
        VisitRequest secondStore = VisitRequest.builder().storeId("store-2").build();

        String first = service.locationVisitDocumentId(
                "user-1", firstStore, LocalDate.of(2026, 8, 19));
        String otherStore = service.locationVisitDocumentId(
                "user-1", secondStore, LocalDate.of(2026, 8, 19));
        String nextDay = service.locationVisitDocumentId(
                "user-1", firstStore, LocalDate.of(2026, 8, 20));

        assertThat(first).isNotEqualTo(otherStore).isNotEqualTo(nextDay);
    }
}
