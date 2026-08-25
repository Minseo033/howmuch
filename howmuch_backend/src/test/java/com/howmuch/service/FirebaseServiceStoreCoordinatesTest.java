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
}
