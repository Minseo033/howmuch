package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.*;
import com.howmuch.dto.ReviewRequest;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.Mockito.*;

class FirebaseServiceReviewIdentityTest {
    private final Firestore db = mock(Firestore.class);
    private final FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

    @Test
    void keepsSameNameBranchesSeparateAndDoesNotGuessLegacyOwnership() throws Exception {
        catalog(List.of(store("store_mokpo", "경남식당", "목포"),
                store("store_danyang", "경남식당", "단양")));
        CollectionReference reviews = mock(CollectionReference.class);
        when(db.collection("reviews")).thenReturn(reviews);
        query(reviews, "store_mokpo", List.of(review("mokpo-review", "store_mokpo")));
        query(reviews, "store_danyang", List.of(review("danyang-review", "store_danyang")));

        assertThat(service.getReviews("store_mokpo"))
                .extracting(row -> row.get("id")).containsExactly("mokpo-review");
        assertThat(service.getReviews("store_danyang"))
                .extracting(row -> row.get("id")).containsExactly("danyang-review");
        assertThat(service.getReviews("경남식당")).isEmpty();
        verify(reviews, never()).whereEqualTo("storeId", "경남식당");
    }

    @Test
    void uniqueLegacyReviewsRemainVisibleUnderTheCanonicalIdWithoutDatabaseWrites() throws Exception {
        catalog(List.of(store("store_unique", "고유식당", "서울")));
        CollectionReference reviews = mock(CollectionReference.class);
        when(db.collection("reviews")).thenReturn(reviews);
        query(reviews, "store_unique", List.of(review("new", "store_unique")));
        QueryDocumentSnapshot legacy = review("old", "고유식당");
        query(reviews, "고유식당", List.of(legacy));

        var result = service.getReviews("store_unique");

        assertThat(result).extracting(row -> row.get("id")).containsExactlyInAnyOrder("new", "old");
        assertThat(result).allSatisfy(row -> assertThat(row.get("storeId")).isEqualTo("store_unique"));
        verify(legacy, never()).getReference();
        assertThat(service.getReviews("고유식당")).hasSize(2);
    }

    @Test
    void legacyNameWriteIsCanonicalizedOnlyWhenTheStoreIsUnique() throws Exception {
        catalog(List.of(store("store_unique", "고유식당", "서울")));
        CollectionReference reviews = mock(CollectionReference.class);
        DocumentReference document = mock(DocumentReference.class);
        when(db.collection("reviews")).thenReturn(reviews);
        when(reviews.document()).thenReturn(document);
        when(document.set(anyMap())).thenReturn(ApiFutures.immediateFuture(null));
        when(document.getId()).thenReturn("new-review");

        assertThat(service.saveReview("user-1", request("고유식당", "고유식당")))
                .isEqualTo("new-review");

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> data = ArgumentCaptor.forClass(Map.class);
        verify(document).set(data.capture());
        assertThat(data.getValue()).containsEntry("storeId", "store_unique")
                .containsEntry("storeName", "고유식당").containsEntry("storeAddress", "서울");
    }

    @Test
    void rejectsAmbiguousNamesUnknownIdsAndMismatchedNamesBeforeWriting() {
        catalog(List.of(store("store_a", "경남식당", "목포"),
                store("store_b", "경남식당", "단양")));

        for (ReviewRequest request : List.of(request("경남식당", "경남식당"),
                request("store_unknown", "경남식당"), request("store_a", "다른식당"))) {
            assertThatThrownBy(() -> service.saveReview("user-1", request))
                    .isInstanceOf(IllegalArgumentException.class);
        }
        verifyNoInteractions(db);
    }

    @Test
    void aNonPublicReportCannotBecomeAReviewTarget() throws Exception {
        ReflectionTestUtils.setField(service, "cachedUserStores", List.of(Map.of(
                "storeId", "store_pending", "storeName", "대기식당", "address", "서울",
                "status", "PENDING")));
        assertThat(service.getReviews("store_pending")).isEmpty();
        assertThatThrownBy(() -> service.saveReview("user-1", request("store_pending", "대기식당")))
                .isInstanceOf(IllegalArgumentException.class);
        verifyNoInteractions(db);
    }

    private void catalog(List<Map<String, Object>> stores) {
        ReflectionTestUtils.setField(service, "cachedStores", stores);
    }

    private Map<String, Object> store(String id, String name, String address) {
        return Map.of("storeId", id, "storeName", name, "address", address);
    }

    private ReviewRequest request(String id, String name) {
        return ReviewRequest.builder().storeId(id).storeName(name).authorName("사용자")
                .menu("백반").price(7000).content("리뷰 내용").stars(4).build();
    }

    private QueryDocumentSnapshot review(String id, String storeId) {
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        when(document.getId()).thenReturn(id);
        when(document.getData()).thenReturn(Map.of("storeId", storeId, "content", id));
        return document;
    }

    private void query(CollectionReference reviews, String storeId, List<QueryDocumentSnapshot> documents) {
        Query query = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(reviews.whereEqualTo("storeId", storeId)).thenReturn(query);
        when(query.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.getDocuments()).thenReturn(documents);
    }
}
