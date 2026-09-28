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
    void preservesSecondaryMenuPricesAndStoreIdentityInRecommendations() {
        var store = new java.util.HashMap<String, Object>();
        store.putAll(Map.of("storeId", "gov-test", "storeName", "여름 식당",
                "industry", "한식", "menu1", "백반", "price1", "6500",
                "menu2", "냉면", "price2", "8000", "source", "GOV",
                "latitude", 37.5666, "longitude", 126.9781));
        ReflectionTestUtils.setField(service, "cachedStores", List.of(store));

        var pick = service.getTodaysPicks("맑음", 32, 37.5665, 126.9780).getFirst();

        assertThat(pick.get("matchedMenu")).isEqualTo("냉면");
        assertThat(pick.get("menu2")).isEqualTo("냉면");
        assertThat(pick.get("price2")).isEqualTo("8000");
        assertThat(pick.get("storeId")).isEqualTo("gov-test");
        assertThat(pick.get("source")).isEqualTo("GOV");
    }

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
    void enrichesFavoriteDetailsFromThePublicCatalogByStableId() {
        ReflectionTestUtils.setField(service, "cachedStores", List.of(Map.ofEntries(
                Map.entry("storeId", "store_detail_id"),
                Map.entry("storeName", "동명 식당"),
                Map.entry("address", "서울시 중구 1"),
                Map.entry("phoneNumber", "02-1234-5678"),
                Map.entry("industry", "한식"),
                Map.entry("menu1", "백반"),
                Map.entry("price1", "6500"),
                Map.entry("menu2", "냉면"),
                Map.entry("price2", "8000"),
                Map.entry("latitude", 37.5665),
                Map.entry("longitude", 126.9780))));

        var favorite = service.favoriteResponse("favorite-doc", Map.of(
                "storeId", "store_detail_id",
                "storeName", "동명 식당",
                "createdAt", "2026-09-23T00:00:00Z"));

        assertThat(favorite.getStoreId()).isEqualTo("store_detail_id");
        assertThat(favorite.getPhoneNumber()).isEqualTo("02-1234-5678");
        assertThat(favorite.getMenu2()).isEqualTo("냉면");
        assertThat(favorite.getPrice2()).isEqualTo("8000");
        assertThat(favorite.getLatitude()).isEqualTo(37.5665);
        assertThat(favorite.getLongitude()).isEqualTo(126.9780);
        assertThat(favorite.getSource()).isEqualTo("GOV");
    }

    @Test
    void keepsDeletedFavoriteLightweightInsteadOfInventingCoordinates() {
        var favorite = service.favoriteResponse("favorite-doc", Map.of(
                "storeId", "deleted-store-id",
                "storeName", "삭제된 매장"));

        assertThat(favorite.getLatitude()).isNull();
        assertThat(favorite.getLongitude()).isNull();
        assertThat(favorite.getPhoneNumber()).isNull();
        assertThat(favorite.getSource()).isNull();
    }

    @Test
    void preservesUserSourceWhenAnApprovedUserStoreIsFavorited() {
        ReflectionTestUtils.setField(service, "cachedUserStores", List.of(Map.of(
                "storeId", "store_user_detail",
                "storeName", "사용자 제보 매장",
                "status", "APPROVED",
                "industry", "카페",
                "latitude", 37.5665,
                "longitude", 126.9780)));

        var favorite = service.favoriteResponse("favorite-doc", Map.of(
                "storeId", "store_user_detail",
                "storeName", "사용자 제보 매장"));

        assertThat(favorite.getSource()).isEqualTo("USER");
        assertThat(favorite.getLatitude()).isEqualTo(37.5665);
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

    @Test
    void constrainsRecommendationRadiusAndLimitsPicksToThree() {
        // User is at Seoul City Hall (37.5665, 126.9780)
        // 4 nearby stores within 500m
        var near1 = Map.of("storeName", "근처 국수집", "industry", "한식",
                "menu1", "국수", "price1", "4000",
                "latitude", 37.5670, "longitude", 126.9780);
        var near2 = Map.of("storeName", "근처 국밥집", "industry", "한식",
                "menu1", "국밥", "price1", "6000",
                "latitude", 37.5680, "longitude", 126.9780);
        var near3 = Map.of("storeName", "근처 라면집", "industry", "한식",
                "menu1", "라면", "price1", "3500",
                "latitude", 37.5690, "longitude", 126.9780);
        var near4 = Map.of("storeName", "근처 백반집", "industry", "한식",
                "menu1", "백반", "price1", "6500",
                "latitude", 37.5700, "longitude", 126.9780);
        // 1 far store 29km away matching alternative theme ("비 오면 파전")
        var farAlt = Map.of("storeName", "29km 원거리 파전집", "industry", "한식",
                "menu1", "해물파전", "price1", "12000",
                "latitude", 37.4000, "longitude", 126.7000);

        ReflectionTestUtils.setField(service, "cachedStores",
                List.of(near1, near2, near3, near4, farAlt));

        List<Map<String, Object>> picks = service.getTodaysPicks(
                "비", 18, 37.5665, 126.9780);

        // Far store (29km) cannot enter the local recommendation picks
        assertThat(picks).extracting(p -> p.get("storeName"))
                .doesNotContain("29km 원거리 파전집")
                .hasSize(3);

        // Every pick must have distance <= 5000m, and non-empty theme and reason
        assertThat(picks).allSatisfy(pick -> {
            int dist = (Integer) pick.get("distanceMeters");
            assertThat(dist).isLessThanOrEqualTo(3000);
            assertThat(pick.get("theme")).isNotNull();
            assertThat(pick.get("theme").toString()).isNotBlank();
            assertThat(pick.get("reason")).isNotNull();
            assertThat(pick.get("reason").toString()).isNotBlank();
        });
    }

    @Test
    void balancesMealsWithNearbyDessertAndNeverExpandsPastThreeKilometers() {
        var meal1 = Map.of("storeName", "가까운 국밥집", "industry", "한식",
                "menu1", "국밥", "price1", "6000",
                "latitude", 37.5670, "longitude", 126.9780);
        var meal2 = Map.of("storeName", "가까운 백반집", "industry", "한식",
                "menu1", "백반", "price1", "6500",
                "latitude", 37.5680, "longitude", 126.9780);
        var meal3 = Map.of("storeName", "가까운 덮밥집", "industry", "한식",
                "menu1", "덮밥", "price1", "7000",
                "latitude", 37.5690, "longitude", 126.9780);
        var dessert = Map.of("storeName", "가까운 카페", "industry", "기타요식업",
                "menu1", "아메리카노", "price1", "2500",
                "latitude", 37.5700, "longitude", 126.9780);
        var tooFarDessert = Map.of("storeName", "4km 밖 카페", "industry", "기타요식업",
                "menu1", "카페라떼", "price1", "3000",
                "latitude", 37.6030, "longitude", 126.9780);

        ReflectionTestUtils.setField(service, "cachedStores",
                List.of(meal1, meal2, meal3, dessert, tooFarDessert));

        List<Map<String, Object>> picks = service.getTodaysPicks(
                "맑음", 20, 37.5665, 126.9780);

        assertThat(picks).hasSize(3);
        assertThat(picks).extracting(pick -> pick.get("storeName"))
                .contains("가까운 카페")
                .doesNotContain("4km 밖 카페");
        assertThat(picks.stream().filter(pick ->
                "가까운 국밥집".equals(pick.get("storeName"))
                        || "가까운 백반집".equals(pick.get("storeName"))
                        || "가까운 덮밥집".equals(pick.get("storeName"))).count())
                .isEqualTo(2);
    }

    @Test
    void returnsFewerPicksInsteadOfPullingInDistantStores() {
        var near = Map.of("storeName", "유일한 근처 식당", "industry", "한식",
                "menu1", "백반", "price1", "6500",
                "latitude", 37.5670, "longitude", 126.9780);
        var far = Map.of("storeName", "멀리 있는 식당", "industry", "한식",
                "menu1", "백반", "price1", "6500",
                "latitude", 37.6030, "longitude", 126.9780);
        ReflectionTestUtils.setField(service, "cachedStores", List.of(near, far));

        List<Map<String, Object>> picks = service.getTodaysPicks(
                "맑음", 20, 37.5665, 126.9780);

        assertThat(picks).extracting(pick -> pick.get("storeName"))
                .containsExactly("유일한 근처 식당");
    }
}
