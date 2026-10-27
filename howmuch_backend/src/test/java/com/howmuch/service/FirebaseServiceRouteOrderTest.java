package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

/** FE-STORE-13: 추천 루트는 총 이동 거리가 가장 짧은 방문 순서입니다. */
class FirebaseServiceRouteOrderTest {
    private final FirebaseService service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));

    @Test
    void routeAvoidsZigZaggingAcrossTheStartingPoint() {
        Map<String, Object> eastNear = stop("east-1.0km", 127.0113);
        Map<String, Object> westMid = stop("west-1.2km", 126.9864);
        Map<String, Object> eastFar = stop("east-1.4km", 127.0159);
        // 출발지 거리순(동1.0 → 서1.2 → 동1.4)은 출발지를 두 번 가로지릅니다.
        List<Map<String, Object>> ordered = service.orderRouteStops(List.of(eastNear, westMid, eastFar), 37.5, 127.0);

        assertThat(ordered).extracting(stop -> stop.get("storeId"))
                .containsExactly("west-1.2km", "east-1.0km", "east-1.4km");
    }

    @Test
    void keepsTheOriginalOrderWithoutUsableCoordinates() {
        List<Map<String, Object>> picks = List.of(stop("a", 127.01), Map.of("storeId", "b"), stop("c", 127.02));

        assertThat(service.orderRouteStops(picks, 37.5, 127.0)).isSameAs(picks);
        assertThat(service.orderRouteStops(picks, null, null)).isSameAs(picks);
    }

    private Map<String, Object> stop(String id, double longitude) {
        return Map.of("storeId", id, "latitude", 37.5, "longitude", longitude);
    }
}

