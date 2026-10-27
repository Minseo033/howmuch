package com.howmuch.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.cloud.firestore.Firestore;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class FirebaseServiceCatalogOptimizationTest {
    private FirebaseService service() {
        return new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
    }

    @Test
    @SuppressWarnings("unchecked")
    void reusesGeneratedRuntimeIdsWithoutAddingThemToTheRefreshSnapshot() throws Exception {
        var service = service();
        var raw = new HashMap<String, Object>(Map.of(
                "storeName", "  기준\t식당  ", "address", "서울\n중구  1", "phoneNumber", "02-1234-5678"));
        String expected = legacyId(raw);
        ReflectionTestUtils.invokeMethod(service, "installGovStores", List.of(raw));
        var runtime = (List<Map<String, Object>>) ReflectionTestUtils.getField(service, "cachedStores");
        assertThat(runtime.getFirst()).containsEntry("storeId", expected);
        assertThat(service.getAllStores().stream().filter(s -> raw.get("storeName").equals(s.get("storeName"))).findFirst().orElseThrow())
                .containsEntry("storeId", expected);
        assertThat(raw).doesNotContainKey("storeId");
        assertThat(service.getGovStoresSnapshot().getFirst()).isEqualTo(raw).doesNotContainKey("storeId");
    }

    @Test
    void precompiledNormalizationKeepsLegacyIdsAndExistingNonblankIds() throws Exception {
        var service = service();
        var raw = new HashMap<String, Object>(Map.of("storeName", " A\t한글😀 식당 ",
                "address", "서울\n중구\u00a01", "phoneNumber", " 02-1234-5678 "));
        ReflectionTestUtils.setField(service, "cachedStores", List.of(raw));
        assertThat(service.getAllStores().getFirst()).containsEntry("storeId", legacyId(raw));
        var existing = new HashMap<>(raw);
        existing.put("storeId", "legacy-explicit-id");
        ReflectionTestUtils.setField(service, "cachedStores", List.of(existing));
        assertThat(service.getAllStores().getFirst()).containsEntry("storeId", "legacy-explicit-id");
    }

    @Test
    @SuppressWarnings("unchecked")
    void freezesReviewedNestedValuesOnceWithoutRetainingMutableInputs() {
        var service = service();
        var imageUrls = new java.util.ArrayList<>(List.of("https://example.test/store.jpg"));
        var period = new HashMap<String, Object>(Map.of("day", "월", "text", "09:00~18:00"));
        var hours = new HashMap<String, Object>(Map.of("periods", new java.util.ArrayList<>(List.of(period)), "imageUrls", imageUrls));
        var catalog = mock(StoreHoursCatalog.class);
        when(catalog.findFor(anyMap())).thenReturn(hours);
        service.setStoreHoursCatalog(catalog);
        ReflectionTestUtils.setField(service, "cachedStores", List.of(Map.of("storeId", "store-a", "storeName", "불변 매장")));
        var before = service.getPublicStoreCatalog();
        var frozen = (Map<String, Object>) before.stores().getFirst().get("openingHours");
        var frozenPeriods = (List<Map<String, Object>>) frozen.get("periods");
        period.put("text", "외부 수정");
        imageUrls.add("https://example.test/later.jpg");
        hours.clear();
        assertThat(frozenPeriods.getFirst()).containsEntry("text", "09:00~18:00");
        assertThat((List<?>) frozen.get("imageUrls")).hasSize(1);
        assertThatThrownBy(() -> frozenPeriods.getFirst().put("day", "화")).isInstanceOf(UnsupportedOperationException.class);
        assertThatThrownBy(() -> frozen.put("new", "value")).isInstanceOf(UnsupportedOperationException.class);
        assertThat(service.getPublicStoreCatalog().etag()).isEqualTo(before.etag());
    }

    @Test
    void streamingTagHashesExactlyTheServedJsonIncludingUnicodeNullsAndCorrections() throws Exception {
        var service = service();
        var raw = new HashMap<String, Object>(Map.of("storeId", "store-a", "storeName", "한글😀 \"식당\"", "price1", "5000"));
        raw.put("menu2", null);
        ReflectionTestUtils.setField(service, "cachedStores", List.of(raw));
        var original = service.getPublicStoreCatalog();
        assertTagMatchesJson(original);
        ReflectionTestUtils.setField(service, "cachedStoreCorrections", Map.of("store-a",
                Map.of("fields", Map.of("price1", "0", "free1", true), "revision", 1L)));
        var corrected = service.getPublicStoreCatalog();
        assertTagMatchesJson(corrected);
        assertThat(corrected.etag()).isNotEqualTo(original.etag());
        assertThat(original.stores().getFirst()).containsEntry("price1", "5000");
        assertThat(corrected.stores().getFirst()).containsEntry("price1", "0").containsEntry("free1", true);
    }

    private void assertTagMatchesJson(FirebaseService.PublicStoreCatalog catalog) throws Exception {
        byte[] bytes = new ObjectMapper().writeValueAsBytes(catalog.stores());
        String digest = java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        assertThat(catalog.etag()).isEqualTo("\"" + digest + "\"");
    }

    private String legacyId(Map<String, Object> raw) throws Exception {
        String canonical = java.util.stream.Stream.of("storeName", "address", "phoneNumber")
                .map(key -> String.valueOf(raw.get(key)).trim().replaceAll("\\s+", " ").toLowerCase())
                .collect(java.util.stream.Collectors.joining("|"));
        byte[] hash = MessageDigest.getInstance("SHA-256").digest(canonical.getBytes(StandardCharsets.UTF_8));
        return "store_" + java.util.HexFormat.of().formatHex(hash, 0, 12);
    }
}
