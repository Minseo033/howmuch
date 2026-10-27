package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** 계약 C6: 잘린 범위 응답에는 X-Stores-Truncated: true 헤더가 붙습니다. */
class StoresControllerBoundsTruncationTest {
    private final FirebaseService firebaseService = mock(FirebaseService.class);
    private final StoresController controller = new StoresController(firebaseService);

    @Test
    void truncatedResultsCarryTheHeader() {
        List<Map<String, Object>> stores = List.of(Map.of("storeId", "store_a"));
        when(firebaseService.getStoresInBoundsPage(37.4, 37.6, 126.9, 127.1))
                .thenReturn(new FirebaseService.BoundsResult(stores, true));

        ResponseEntity<?> response = controller.getStoresInBounds(37.4, 37.6, 126.9, 127.1);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getHeaders().getFirst("X-Stores-Truncated")).isEqualTo("true");
        assertThat(response.getBody()).isEqualTo(stores);
    }

    @Test
    void completeResultsHaveNoTruncationHeader() {
        when(firebaseService.getStoresInBoundsPage(37.4, 37.6, 126.9, 127.1))
                .thenReturn(new FirebaseService.BoundsResult(List.of(), false));

        ResponseEntity<?> response = controller.getStoresInBounds(37.4, 37.6, 126.9, 127.1);

        assertThat(response.getHeaders().containsKey("X-Stores-Truncated")).isFalse();
        assertThat(response.getBody()).isEqualTo(List.of());
    }
}

