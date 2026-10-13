package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

class FirebaseServiceTodaysPickPerformanceTest {
    @Test
    void denseAreaKeepsNearestRankingWithoutReparsingCoordinatesInEverySortComparison() {
        var service = spy(new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class)));
        List<CountingStore> stores = new ArrayList<>();
        for (int i = 0; i < 400; i++) {
            var store = new CountingStore();
            store.putAll(Map.of("storeId", "store-" + i, "storeName", "식당 " + i,
                    "industry", "한식", "menu1", "국밥", "price1", "7000",
                    "latitude", 37.5 + i * .00001, "longitude", 127.0));
            stores.add(store);
        }
        Collections.shuffle(stores, new Random(42));
        List<Map<String, Object>> catalog = new ArrayList<>(stores);
        doReturn(catalog).when(service).getAllStores();

        var picks = service.getTodaysPicks("비", 20, 37.5, 127.0, 3000);

        assertThat(picks).extracting(pick -> pick.get("storeId"))
                .containsExactly("store-0", "store-1", "store-2");
        assertThat(picks).allSatisfy(pick -> assertThat((int) pick.get("distanceMeters")).isBetween(0, 3000));
        assertThat(stores.stream().mapToInt(store -> store.coordinateReads).sum())
                .isLessThanOrEqualTo(400 * 4 + 30);
    }

    private static class CountingStore extends HashMap<String, Object> {
        int coordinateReads;
        @Override
        public Object get(Object key) {
            if ("latitude".equals(key) || "longitude".equals(key)) coordinateReads++;
            return super.get(key);
        }
    }
}
