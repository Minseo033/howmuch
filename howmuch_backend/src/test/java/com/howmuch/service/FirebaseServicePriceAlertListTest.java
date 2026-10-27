package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.howmuch.dto.PriceAlertSubscriptionDto;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** BE-CORE-5: 가격 알림 목록은 승인된 보정이 반영된 가격을 보여줍니다. */
class FirebaseServicePriceAlertListTest {
    @Test
    void subscriptionsShowCorrectedPricesAndFallBackToTheNextRegisteredMenu() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference favorites = mock(CollectionReference.class);
        Query byUser = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(db.collection("favorites")).thenReturn(favorites);
        when(favorites.whereEqualTo("userId", "user-1")).thenReturn(byUser);
        when(byUser.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        QueryDocumentSnapshot corrected = favorite(Map.of("userId", "user-1", "storeId", "store_a", "storeName", "국밥집"));
        QueryDocumentSnapshot menuRemoved = favorite(Map.of("userId", "user-1", "storeId", "store_b", "storeName", "냉면집"));
        List<QueryDocumentSnapshot> documents = List.of(corrected, menuRemoved);
        when(snapshot.getDocuments()).thenReturn(documents);
        CollectionReference settings = mock(CollectionReference.class);
        DocumentReference settingsRef = mock(DocumentReference.class);
        DocumentSnapshot missing = mock(DocumentSnapshot.class);
        when(db.collection("notification_settings")).thenReturn(settings);
        when(settings.document("user-1")).thenReturn(settingsRef);
        when(settingsRef.get()).thenReturn(ApiFutures.immediateFuture(missing));

        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(service, "cachedStores", List.of(
                Map.of("storeId", "store_a", "storeName", "국밥집", "address", "서울", "menu1", "국밥", "price1", "6000"),
                Map.of("storeId", "store_b", "storeName", "냉면집", "address", "부산",
                        "menu1", "물냉면", "price1", "8000", "menu2", "비빔냉면", "price2", "8500")));
        ReflectionTestUtils.setField(service, "cachedStoreCorrections", Map.of(
                "store_a", Map.of("fields", Map.of("price1", "6500"), "revision", 1L),
                "store_b", Map.of("fields", Map.of("menu1", "", "price1", "", "free1", false), "revision", 1L)));

        List<PriceAlertSubscriptionDto> result = service.getPriceAlertSubscriptions("user-1");

        assertThat(result).extracting(PriceAlertSubscriptionDto::getStoreId).containsExactly("store_a", "store_b");
        assertThat(result).extracting(PriceAlertSubscriptionDto::getMenuName).containsExactly("국밥", "비빔냉면");
        assertThat(result).extracting(PriceAlertSubscriptionDto::getPrice).containsExactly("6500", "8500");
    }

    private QueryDocumentSnapshot favorite(Map<String, Object> data) {
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        when(document.getData()).thenReturn(data);
        return document;
    }
}

