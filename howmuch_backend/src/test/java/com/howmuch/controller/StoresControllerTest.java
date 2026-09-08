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
        when(service.getAllStores()).thenReturn(stores);

        ResponseEntity<?> response = controller.getAllStores();

        assertEquals(200, response.getStatusCode().value());
        assertEquals(stores, response.getBody());
        verify(service).getAllStores();
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
