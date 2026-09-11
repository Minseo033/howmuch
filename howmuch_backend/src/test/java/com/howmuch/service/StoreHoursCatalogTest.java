package com.howmuch.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.cloud.firestore.Firestore;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

class StoreHoursCatalogTest {
    private static final String ID = "store_0123456789abcdef01234567";

    private StoreHoursCatalog.Entry entry(String status, String date) {
        return new StoreHoursCatalog.Entry(ID, "같은이름식당", "서울특별시 강동구 천중로 73", "02-123-4567",
                status, "18:00~익일 02:00\n매주 월요일 휴무", "행정안전부 착한가격업소",
                "https://www.goodprice.go.kr/bssh/bsshInfo.do?bsshSn=104", date, true, false, "서울페이");
    }

    private Map<String, Object> store() {
        return new HashMap<>(Map.of("storeId", ID, "storeName", "같은이름식당",
                "address", "서울특별시 강동구 천중로 73", "phoneNumber", "02-123-4567",
                "latitude", 37.55, "longitude", 127.12));
    }

    @Test
    void servesReviewedHoursInBothCatalogAndBoundsWithoutPollutingThePublicSnapshot() {
        var db = mock(Firestore.class);
        var service = new FirebaseService(db, mock(ReportImageStorage.class));
        service.setStoreHoursCatalog(new StoreHoursCatalog(List.of(entry("SOURCE_VERIFIED", "2026-09-11"))));
        var raw = store();
        raw.put("openingHours", Map.of("text", "unreviewed upstream value"));
        ReflectionTestUtils.setField(service, "cachedStores", List.of(raw));

        Map<?, ?> allHours = (Map<?, ?>) service.getAllStores().getFirst().get("openingHours");
        assertThat(allHours.get("text")).isEqualTo("18:00~익일 02:00\n매주 월요일 휴무");
        assertThat(service.getStoresInBounds(37.5, 37.6, 127.1, 127.2).getFirst().get("openingHours")).isEqualTo(allHours);
        assertThat(service.getGovStoresSnapshot().getFirst().get("openingHours"))
                .isEqualTo(Map.of("text", "unreviewed upstream value"));
        // A later public-data refresh replaces the raw cache but cannot erase the separate hours.
        ReflectionTestUtils.setField(service, "cachedStores", List.of(store()));
        assertThat(service.getAllStores().getFirst().get("openingHours")).isEqualTo(allHours);
        assertThat(service.getGovStoresSnapshot().getFirst()).doesNotContainKey("openingHours");
        verifyNoInteractions(db);
    }

    @Test
    void refusesAmbiguousUnreviewedFutureAndMovedStoreRecords() {
        var valid = entry("SOURCE_VERIFIED", "2026-09-11");
        var catalog = new StoreHoursCatalog(List.of(valid));
        var moved = store();
        moved.put("address", "서울특별시 강동구 천중로 75");
        assertThat(catalog.findFor(moved)).isNull();
        assertThat(new StoreHoursCatalog(List.of(valid, valid)).findFor(store())).isNull();
        assertThat(new StoreHoursCatalog(List.of(entry("SOURCE_MATCHED", "2026-09-11"))).findFor(store())).isNull();
        assertThat(new StoreHoursCatalog(List.of(entry("SOURCE_VERIFIED", "2099-01-01"))).findFor(store())).isNull();
        assertThat(new StoreHoursCatalog(List.of(entry("SOURCE_VERIFIED", "2026-02-30"))).findFor(store())).isNull();
    }

    @Test
    void bundledRecordsHaveValidSourcesUniqueIdsAndAnExactCatalogIdentity() throws Exception {
        var mapper = new ObjectMapper();
        List<StoreHoursCatalog.Entry> records;
        List<Map<String, Object>> stores;
        try (var input = new ClassPathResource("store-hours.json").getInputStream()) {
            records = mapper.readValue(input, new TypeReference<>() {});
        }
        try (var input = new ClassPathResource("stores-snapshot.json").getInputStream()) {
            stores = mapper.readValue(input, new TypeReference<>() {});
        }
        assertThat(records).allMatch(StoreHoursCatalog.Entry::valid);
        assertThat(records.stream().map(StoreHoursCatalog.Entry::storeId).toList()).doesNotHaveDuplicates();
        var service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(service, "cachedStores", stores);
        var catalog = new StoreHoursCatalog(records);
        assertThat(service.getAllStores().stream().filter(row -> catalog.findFor(row) != null).count()).isEqualTo(records.size());
    }
}
