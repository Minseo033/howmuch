package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verifyNoInteractions;

class StoresControllerTest {

    @Test
    @SuppressWarnings("unchecked")
    void lightCatalogRetainsEveryStoreAndSearchFieldButDefersHoursAndPhotos() {
        FirebaseService service = mock(FirebaseService.class);
        StoresController controller = new StoresController(service);
        var stores = java.util.stream.IntStream.range(0, 11391).mapToObj(index -> {
            java.util.Map<String, Object> store = new java.util.HashMap<>();
            store.put("storeId", "store-" + index);
            store.put("storeName", "전국 매장 " + index);
            store.put("address", "서울특별시 종로구 1");
            store.put("phoneNumber", "02-123-4567");
            store.put("latitude", 37.5);
            store.put("longitude", 127.0);
            store.put("industry", "분식");
            store.put("source", "GOV");
            store.put("correctionRevision", 2);
            for (int slot = 1; slot <= 4; slot++) {
                store.put("menu" + slot, "메뉴 " + slot);
                store.put("price" + slot, slot == 4 ? "0" : "3000 / 3500");
                store.put("free" + slot, slot == 4);
            }
            store.put("openingHours", java.util.Map.of("text", "09:00~18:00", "imageUrls", java.util.List.of("https://example.test/store.jpg")));
            return store;
        }).toList();
        when(service.getPublicStoreCatalog()).thenReturn(new FirebaseService.PublicStoreCatalog(stores, "\"catalog-a\""));

        var response = controller.getMapCatalog(null);
        var light = (java.util.List<java.util.Map<String, Object>>) response.getBody();
        assertEquals(11391, light.size());
        assertEquals("\"catalog-a-map-v1\"", response.getHeaders().getETag());
        for (int index = 0; index < stores.size(); index++) {
            var expected = new java.util.HashMap<>(stores.get(index));
            expected.remove("openingHours");
            assertEquals(expected, light.get(index));
        }
        assertSame(light, controller.getMapCatalog(null).getBody());
        assertEquals(stores, controller.getAllStores(null).getBody());
        assertTrue(stores.getFirst().containsKey("openingHours"));
        assertEquals(200, controller.getMapCatalog("\"catalog-a\"").getStatusCode().value());
        assertEquals(304, controller.getMapCatalog("W/\"catalog-a-map-v1\"").getStatusCode().value());
    }

    @Test
    @SuppressWarnings("unchecked")
    void lightProjectionIsReadOnlyAndItsIteratorSkipsOnlyTheDetailField() {
        FirebaseService service = mock(FirebaseService.class);
        StoresController controller = new StoresController(service);
        var original = new java.util.LinkedHashMap<String, Object>();
        original.put("openingHours", java.util.Map.of("text", "09:00~18:00"));
        original.put("storeId", "store-a");
        original.put("menu1", null);
        original.put("price1", "0");
        when(service.getPublicStoreCatalog()).thenReturn(new FirebaseService.PublicStoreCatalog(
                java.util.List.of(java.util.Collections.unmodifiableMap(original), java.util.Map.of("openingHours", "detail only")), "\"catalog-a\""));
        var stores = (java.util.List<java.util.Map<String, Object>>) controller.getMapCatalog(null).getBody();
        var light = stores.getFirst();
        assertEquals(3, light.size());
        assertTrue(light.containsKey("menu1"));
        assertFalse(light.containsKey("openingHours"));
        assertEquals(null, light.get("openingHours"));
        assertEquals(java.util.List.of("storeId", "menu1", "price1"), new java.util.ArrayList<>(light.keySet()));
        assertEquals(java.util.Arrays.asList("store-a", null, "0"), new java.util.ArrayList<>(light.values()));
        var expected = new java.util.HashMap<>(original);
        expected.remove("openingHours");
        assertEquals(light, expected);
        assertEquals(expected.hashCode(), light.hashCode());
        org.junit.jupiter.api.Assertions.assertThrows(UnsupportedOperationException.class, () -> light.keySet().remove("price1"));
        org.junit.jupiter.api.Assertions.assertThrows(UnsupportedOperationException.class, () -> light.values().remove("0"));
        var iterator = light.entrySet().iterator();
        assertTrue(iterator.hasNext());
        assertTrue(iterator.hasNext());
        var entry = iterator.next();
        assertEquals("storeId", entry.getKey());
        org.junit.jupiter.api.Assertions.assertThrows(UnsupportedOperationException.class, () -> entry.setValue("changed"));
        org.junit.jupiter.api.Assertions.assertThrows(UnsupportedOperationException.class, iterator::remove);
        org.junit.jupiter.api.Assertions.assertThrows(UnsupportedOperationException.class, () -> light.put("storeId", "changed"));
        org.junit.jupiter.api.Assertions.assertThrows(UnsupportedOperationException.class, () -> light.remove("price1"));
        org.junit.jupiter.api.Assertions.assertThrows(UnsupportedOperationException.class, light::clear);
        org.junit.jupiter.api.Assertions.assertThrows(UnsupportedOperationException.class, () -> stores.add(java.util.Map.of()));
        assertTrue(stores.get(1).isEmpty());
        org.junit.jupiter.api.Assertions.assertThrows(java.util.NoSuchElementException.class, () -> stores.get(1).entrySet().iterator().next());
        assertEquals("store-a", original.get("storeId"));
        assertTrue(original.containsKey("openingHours"));
    }

    @Test
    void lightCatalogRefreshesWhenTheCanonicalSnapshotChanges() {
        FirebaseService service = mock(FirebaseService.class);
        StoresController controller = new StoresController(service);
        var original = java.util.List.of(java.util.Map.<String, Object>of("price1", "6500"));
        var corrected = java.util.List.of(java.util.Map.<String, Object>of("price1", "0", "free1", true));
        when(service.getPublicStoreCatalog()).thenReturn(
                new FirebaseService.PublicStoreCatalog(original, "\"catalog-a\""),
                new FirebaseService.PublicStoreCatalog(corrected, "\"catalog-b\""));
        assertEquals(original, controller.getMapCatalog(null).getBody());
        var response = controller.getMapCatalog("\"catalog-a-map-v1\"");
        assertEquals(200, response.getStatusCode().value());
        assertEquals(corrected, response.getBody());
        assertEquals("\"catalog-b-map-v1\"", response.getHeaders().getETag());
    }

    @Test
    void returnsAllStoresFromTheService() {
        FirebaseService service = mock(FirebaseService.class);
        StoresController controller = new StoresController(service);
        var stores = java.util.List.of(
                java.util.Map.<String, Object>of("storeName", "테스트 식당"));
        when(service.getPublicStoreCatalog()).thenReturn(new FirebaseService.PublicStoreCatalog(stores, "\"catalog-a\""));

        ResponseEntity<?> response = controller.getAllStores(null);

        assertEquals(200, response.getStatusCode().value());
        assertEquals(stores, response.getBody());
        assertTrue(response.getHeaders().getCacheControl().contains("no-cache"));
        assertTrue(response.getHeaders().getCacheControl().contains("public"));
        assertEquals("\"catalog-a\"", response.getHeaders().getETag());
        verify(service).getPublicStoreCatalog();
    }

    @Test
    void matchingStrongOrWeakValidationTagAvoidsResendingTheCatalog() {
        FirebaseService service = mock(FirebaseService.class);
        StoresController controller = new StoresController(service);
        when(service.getPublicStoreCatalog()).thenReturn(new FirebaseService.PublicStoreCatalog(java.util.List.of(), "\"catalog-a\""));
        ResponseEntity<?> response = controller.getAllStores("\"other\", W/\"catalog-a\"");
        assertEquals(304, response.getStatusCode().value());
        assertEquals("\"catalog-a\"", response.getHeaders().getETag());
        assertEquals(null, response.getBody());
    }

    @Test
    void aChangedCatalogReturnsItsNewValidationTagAndBodyTogether() {
        FirebaseService service = mock(FirebaseService.class);
        StoresController controller = new StoresController(service);
        var stores = java.util.List.of(java.util.Map.<String, Object>of("price1", "6500"));
        when(service.getPublicStoreCatalog()).thenReturn(new FirebaseService.PublicStoreCatalog(stores, "\"catalog-b\""));
        ResponseEntity<?> response = controller.getAllStores("\"catalog-a\"");
        assertEquals(200, response.getStatusCode().value());
        assertEquals(stores, response.getBody());
        assertEquals("\"catalog-b\"", response.getHeaders().getETag());
    }

    @Test
    void rejectsInvalidOrExcessivelyLargeBoundsBeforeScanningStores() {
        FirebaseService service = mock(FirebaseService.class);
        StoresController controller = new StoresController(service);

        ResponseEntity<?> reversed = controller.getStoresInBounds(38, 37, 126, 127);
        ResponseEntity<?> tooLarge = controller.getStoresInBounds(30, 50, 120, 130);

        assertEquals(400, reversed.getStatusCode().value());
        assertEquals(400, tooLarge.getStatusCode().value());
        verifyNoInteractions(service);
    }

    @Test
    void validatesFiniteCoordinateRanges() {
        assertTrue(StoresController.isValidBounds(37.4, 37.7, 126.8, 127.2));
        assertFalse(StoresController.isValidBounds(Double.NaN, 37.7, 126.8, 127.2));
        assertFalse(StoresController.isValidBounds(-91, 37.7, 126.8, 127.2));
        assertFalse(StoresController.isValidBounds(37.4, 37.7, 181, 182));
    }

    @Test
    void rejectsInvalidPriceHistoryInputBeforeCallingTheService() {
        FirebaseService service = mock(FirebaseService.class);
        StoresController controller = new StoresController(service);

        ResponseEntity<?> response = controller.getPriceHistory(" ", "메뉴");

        assertEquals(400, response.getStatusCode().value());
        verifyNoInteractions(service);
    }
}
