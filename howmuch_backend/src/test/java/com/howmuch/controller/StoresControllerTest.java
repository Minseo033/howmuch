package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verifyNoInteractions;

class StoresControllerTest {

    @Test
    void returnsAllStoresFromTheService() {
        FirebaseService service = mock(FirebaseService.class);
        StoresController controller = new StoresController(service);
        var stores = java.util.List.of(
                java.util.Map.<String, Object>of("storeName", "테스트 식당"));
        when(service.getPublicStoreCatalog()).thenReturn(new FirebaseService.PublicStoreCatalog(stores, "\"catalog-a\""));

        ResponseEntity<?> response = controller.getAllStores();

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
