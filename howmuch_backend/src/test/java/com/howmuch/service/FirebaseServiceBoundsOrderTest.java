package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

/** 계약 C6: 지도 범위 조회는 중심 거리순으로 1,200곳 제한하고 잘림 여부를 알려줍니다. */
class FirebaseServiceBoundsOrderTest {
    private final FirebaseService service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));

    @Test
    void truncatesTheFarthestStoresInsteadOfCatalogOrder() {
        List<Map<String, Object>> stores = new ArrayList<>();
        // 카탈로그 앞쪽은 범위 가장자리 매장, 중심 매장은 맨 뒤에 둡니다.
        for (int i = 0; i < 1300; i++) {
            double offset = 0.09 * (1300 - i) / 1300.0;
            stores.add(Map.of("storeId", "store_" + i, "storeName", "가" + i,
                    "latitude", 37.5 + offset, "longitude", 127.0 + offset));
        }
        stores.add(Map.of("storeId", "store_center", "storeName", "하중심", "latitude", 37.5, "longitude", 127.0));
        ReflectionTestUtils.setField(service, "cachedStores", stores);

        FirebaseService.BoundsResult result = service.getStoresInBoundsPage(37.4, 37.6, 126.9, 127.1);

        assertThat(result.truncated()).isTrue();
        assertThat(result.stores()).hasSize(1200);
        assertThat(result.stores().getFirst()).containsEntry("storeId", "store_center");
        assertThat(result.stores()).extracting(store -> store.get("storeId")).doesNotContain("store_0");
    }

    @Test
    void smallResultsAreCompleteAndSortedFromTheCenter() {
        ReflectionTestUtils.setField(service, "cachedStores", List.of(
                Map.of("storeId", "store_far", "storeName", "먼곳", "latitude", 37.58, "longitude", 127.08),
                Map.of("storeId", "store_near", "storeName", "가까운곳", "latitude", 37.501, "longitude", 127.001),
                Map.of("storeId", "store_outside", "storeName", "밖", "latitude", 36.0, "longitude", 127.0)));

        FirebaseService.BoundsResult result = service.getStoresInBoundsPage(37.4, 37.6, 126.9, 127.1);

        assertThat(result.truncated()).isFalse();
        assertThat(result.stores()).extracting(store -> store.get("storeId"))
                .containsExactly("store_near", "store_far");
        assertThat(service.getStoresInBoundsPage(37.4, 37.6, 126.9, 127.1).stores()).hasSize(2);
    }
}
