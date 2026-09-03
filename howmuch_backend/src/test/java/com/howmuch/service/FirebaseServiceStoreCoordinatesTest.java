package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import com.howmuch.dto.StoreCoordinates;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class FirebaseServiceStoreCoordinatesTest {

    private final FirebaseService service = new FirebaseService(
            mock(Firestore.class), mock(ReportImageStorage.class));

    @Test
    void rejectsAStaleStoreIdEvenWhenTheStoreNameMatches() {
        ReflectionTestUtils.setField(service, "cachedStores", List.of(Map.of(
                "storeId", "current-id",
                "storeName", "테스트 식당",
                "latitude", 37.5665,
                "longitude", 126.9780)));

        assertThat(service.findStoreCoordinates("legacy-id", "테스트 식당"))
                .isEmpty();
    }

    @Test
    void fallsBackToAUniqueExactStoreNameOnlyWhenTheClientHasNoStoreId() {
        ReflectionTestUtils.setField(service, "cachedStores", List.of(Map.of(
                "storeId", "current-id",
                "storeName", "테스트 식당",
                "industry", "한식",
                "latitude", 37.5665,
                "longitude", 126.9780)));

        assertThat(service.findStoreCoordinates(null, " 테스트  식당 "))
                .get()
                .satisfies(store -> {
                    assertThat(store.storeId()).isEqualTo("current-id");
                    assertThat(store.industry()).isEqualTo("한식");
                });
    }

    @Test
    void prefersStoreIdWhenDuplicateNamesHaveDifferentCoordinates() {
        ReflectionTestUtils.setField(service, "cachedStores", List.of(
                Map.of("storeId", "first-id", "storeName", "동명 식당",
                        "latitude", 37.1, "longitude", 127.1),
                Map.of("storeId", "target-id", "storeName", "동명 식당",
                        "latitude", 37.2, "longitude", 127.2)));

        assertThat(service.findStoreCoordinates("target-id", "동명 식당"))
                .get()
                .satisfies(store -> {
                    assertThat(store.latitude()).isEqualTo(37.2);
                    assertThat(store.longitude()).isEqualTo(127.2);
                    assertThat(store.storeId()).isEqualTo("target-id");
                });
    }

    @Test
    void rejectsAmbiguousLegacyStoreNames() {
        ReflectionTestUtils.setField(service, "cachedStores", List.of(
                Map.of("storeId", "first-id", "storeName", "동명 식당",
                        "latitude", 37.1, "longitude", 127.1),
                Map.of("storeId", "second-id", "storeName", "동명 식당",
                        "latitude", 37.2, "longitude", 127.2)));

        assertThat(service.findStoreCoordinates(null, "동명 식당")).isEmpty();
    }

    @Test
    void excludesStoresWithMissingOrOutOfRangeCoordinatesFromLocationBasedPicks() {
        ReflectionTestUtils.setField(service, "cachedStores", List.of(
                Map.of("storeName", "정상 국밥집", "industry", "한식",
                        "menu1", "국밥", "price1", "6000",
                        "latitude", 37.5666, "longitude", 126.9781),
                Map.of("storeName", "좌표 없는 국밥집", "industry", "한식",
                        "menu1", "국밥", "price1", "6000"),
                Map.of("storeName", "좌표 오류 국밥집", "industry", "한식",
                        "menu1", "국밥", "price1", "6000",
                        "latitude", 999, "longitude", 126.9781)));

        List<Map<String, Object>> picks = service.getTodaysPicks(
                "비", 20, 37.5665, 126.9780);

        assertThat(picks).extracting(pick -> pick.get("storeName"))
                .containsExactly("정상 국밥집");
        assertThat(picks.getFirst().get("distanceMeters")).isInstanceOf(Integer.class);
    }

    @Test
    void buildsAiContextOnlyFromServerCachedAndApprovedStores() {
        ReflectionTestUtils.setField(service, "cachedStores", List.of(Map.of(
                "storeId", "gov-1", "storeName", "정부 매장",
                "menu1", "국밥", "price1", "6000",
                "latitude", 37.5666, "longitude", 126.9781)));
        ReflectionTestUtils.setField(service, "cachedUserStores", List.of(
                Map.of("storeId", "user-1", "storeName", "승인 매장",
                        "menu1", "백반", "price1", "6500", "status", "APPROVED",
                        "latitude", 37.5667, "longitude", 126.9782),
                Map.of("storeId", "pending-1", "storeName", "검토 중 매장",
                        "status", "PENDING", "latitude", 37.5668, "longitude", 126.9783)));

        List<Map<String, Object>> context = service.getAiStoreContext(
                List.of("user-1", "gov-1", "pending-1", "fabricated-id"),
                37.5665,
                126.9780);

        assertThat(context).extracting(item -> item.get("storeName"))
                .containsExactly("승인 매장", "정부 매장");
        assertThat(context).extracting(item -> item.get("source"))
                .containsExactly("사용자 제보", "착한가격업소");
        assertThat(context).allSatisfy(item ->
                assertThat(item.get("distanceMeters")).isInstanceOf(Integer.class));
    }
}
