package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.mock;

class FirebaseServiceCorrectionCatalogTest {
    private final FirebaseService service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
    private final Map<String, Object> original = Map.of("storeId", "store_a", "storeName", "국밥집", "menu1", "국밥",
            "price1", "6000", "latitude", 37.5, "longitude", 127.0, "address", "서울 중구", "industry", "한식");
    private void setup(Map<String, Object> fields) {
        ReflectionTestUtils.setField(service, "cachedStores", List.of(original));
        ReflectionTestUtils.setField(service, "cachedStoreCorrections", Map.of("store_a", Map.of("fields", fields, "revision", 1L,
                "reviewReason", "내부 검토", "approvedBy", "관리자")));
    }
    @Test void overlayAppliesToBoundsAiTodayAndHistoryWithoutChangingOriginalSource() throws Exception {
        setup(Map.of("price1", "6500", "latitude", 37.51));
        assertThat(service.getAllStores().getFirst()).containsEntry("price1", "6500").containsEntry("source", "GOV")
                .doesNotContainKeys("reviewReason", "approvedBy");
        assertThat(service.getStoresInBoundsPage(37.509, 37.511, 126.99, 127.01).stores()).hasSize(1);
        assertThat(service.getStoresInBoundsPage(37.499, 37.501, 126.99, 127.01).stores()).isEmpty();
        assertThat(service.getAiStoreContext(List.of("store_a"), 37.51, 127.0, RecommendationRadius.DEFAULT_METERS).getFirst())
                .containsEntry("price1", "6500");
        assertThat(service.getTodaysPicks("비", 18, 37.51, 127.0, RecommendationRadius.DEFAULT_METERS).getFirst())
                .containsEntry("price1", "6500");
        assertThat(service.getPriceHistory("store_a", "국밥")).containsEntry("currentPrice", "6500");
        assertThat(original).containsEntry("price1", "6000").containsEntry("latitude", 37.5);
    }
    @Test void closedRemainsInDetailAndFavoriteButNotDiscoveryOrVisit() {
        setup(Map.of("isClosed", true));
        assertThat(service.getAllStores()).isEmpty();
        assertThat(service.getStoreById("store_a")).containsEntry("isClosed", true);
        assertThat(service.getAiStoreContext(List.of("store_a"), 37.5, 127.0, RecommendationRadius.DEFAULT_METERS)).isEmpty();
        assertThat(service.getTodaysPicks("비", 18, 37.5, 127.0, RecommendationRadius.DEFAULT_METERS)).isEmpty();
        assertThat(service.findStoreCoordinates("store_a", "국밥집")).isEmpty();
        assertThat(service.favoriteResponse("favorite", Map.of("storeId", "store_a", "storeName", "국밥집")).getPrice1()).isEqualTo("6000");
    }
    @Test void explicitFreeIsValidatedByCanonicalMenuAndClosedFreeIsNotAvailable() {
        setup(Map.of("price1", "0", "free1", true));
        assertThat(service.isApprovedFreeMenu("store_a", "국밥집", "국밥")).isTrue();
        assertThat(service.isApprovedFreeMenu("store_a", "국밥집", "김밥")).isFalse();
        ReflectionTestUtils.setField(service, "cachedStoreCorrections", Map.of("store_a", Map.of("fields", Map.of("price1", "0"), "revision", 2L)));
        assertThat(service.isApprovedFreeMenu("store_a", "국밥집", "국밥")).isFalse();
    }
    @Test void informationAndPriceReportsAreNeverNewStores() {
        ReflectionTestUtils.setField(service, "cachedUserStores", List.of(
                Map.of("storeId", "info", "storeName", "잘못된 신규 매장", "reportType", "STORE_INFO", "status", "APPROVED"),
                Map.of("storeId", "price", "storeName", "가격 변경", "changeType", "rise", "status", "APPROVED")));
        assertThat(service.getAllStores()).isEmpty();
    }
    @Test void strictRadiusOverridesClientIdsAndSupportsOneThreeFifteenKm() {
        ReflectionTestUtils.setField(service, "cachedStores", List.of(original));
        assertThat(service.getAiStoreContext(List.of("store_a"), 37.52, 127.0, 1000)).isEmpty();
        assertThat(service.getAiStoreContext(List.of("store_a"), 37.52, 127.0, 3000)).hasSize(1);
        assertThat(service.getAiStoreContext(List.of("store_a"), 37.62, 127.0, 15000)).hasSize(1);
        assertThat(service.getAiStoreContext(List.of("store_a"), 37.62, 127.0, 3000)).isEmpty();
        assertThatThrownBy(() -> service.getAiStoreContext(List.of(), 37.5, 127.0, 3500)).isInstanceOf(IllegalArgumentException.class);
    }
    @Test void separateCorrectionsSurviveReplacingGovSnapshotAndNeverEnterRefreshSnapshot() {
        setup(Map.of("price1", "6500"));
        var changedSnapshot = new HashMap<>(original); changedSnapshot.put("price1", "6100");
        ReflectionTestUtils.invokeMethod(service, "installGovStores", List.of(changedSnapshot));
        assertThat(service.getStoreById("store_a")).containsEntry("price1", "6500");
        assertThat(service.getGovStoresSnapshot().getFirst()).containsEntry("price1", "6100").doesNotContainKey("correctionRevision");
    }

    @Test void todaySkipsUnmarkedZeroAndUnknownPricesButAllowsExplicitFree() {
        var zero = new HashMap<>(original); zero.put("price1", "0");
        ReflectionTestUtils.setField(service, "cachedStores", List.of(zero));
        assertThat(service.getTodaysPicks("비", 18, 37.5, 127.0, RecommendationRadius.DEFAULT_METERS)).isEmpty();
        zero.put("free1", true);
        ReflectionTestUtils.setField(service, "cachedStores", List.of(new HashMap<>(zero)));
        assertThat(service.getTodaysPicks("비", 18, 37.5, 127.0, RecommendationRadius.DEFAULT_METERS).getFirst())
                .containsEntry("matchedFree", true);
    }

    @Test void rainyWarmThemeDoesNotClaimBibimNoodlesAreSoupAndUsesKnownSecondaryPrice() {
        var noodle = new HashMap<>(original); noodle.put("menu1", "비빔국수"); noodle.put("price1", "가격 미정");
        noodle.put("menu2", "칼국수"); noodle.put("price2", "6000");
        ReflectionTestUtils.setField(service, "cachedStores", List.of(noodle));
        assertThat(service.getTodaysPicks("비", 18, 37.5, 127.0, RecommendationRadius.DEFAULT_METERS).getFirst())
                .containsEntry("matchedMenu", "칼국수").containsEntry("theme", "따뜻한 국물");
    }

    @Test void validationTagChangesWithPublicCorrectionButNotInternalReviewFields() {
        ReflectionTestUtils.setField(service, "cachedStores", List.of(original));
        String before = service.getPublicStoreCatalog().etag();
        setup(Map.of("price1", "6500"));
        String corrected = service.getPublicStoreCatalog().etag();
        assertThat(corrected).isNotEqualTo(before);
        ReflectionTestUtils.setField(service, "cachedStoreCorrections", Map.of("store_a", Map.of("fields", Map.of("price1", "6500"),
                "revision", 1L, "reviewReason", "다른 내부 사유")));
        assertThat(service.getPublicStoreCatalog().etag()).isEqualTo(corrected);
    }
}
