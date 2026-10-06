package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.VisitRequest;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.ReceiptOcrService;
import com.howmuch.service.SimpleRateLimiter;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** BE-CORE-7: 시작 직후 매장 목록 준비 중에는 404·422 대신 503 + Retry-After */
class CatalogWarmupResponseTest {
    private final FirebaseService firebaseService = mock(FirebaseService.class);

    @Test
    void storeDetailIsRetryableWhileTheCatalogWarmsUp() {
        StoresController controller = new StoresController(firebaseService);
        when(firebaseService.getStoreById("store_user_1")).thenReturn(null);
        when(firebaseService.isStoreCatalogWarmingUp()).thenReturn(true);

        ResponseEntity<?> warming = controller.getStore("store_user_1");
        assertThat(warming.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
        assertThat(warming.getHeaders().getFirst("Retry-After")).isEqualTo("5");

        when(firebaseService.isStoreCatalogWarmingUp()).thenReturn(false);
        assertThat(controller.getStore("store_user_1").getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void locationVisitIsRetryableWhileTheCatalogWarmsUp() {
        VisitController controller = new VisitController(firebaseService, mock(ReceiptOcrService.class),
                mock(SimpleRateLimiter.class));
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        when(firebaseService.findStoreCoordinates(any(), any())).thenReturn(Optional.empty());
        when(firebaseService.isStoreCatalogWarmingUp()).thenReturn(true);
        VisitRequest visit = VisitRequest.builder().storeId("store_a").storeName("국밥집").menu("국밥")
                .price(8000L).verificationMethod("LOCATION").latitude(37.5).longitude(127.0)
                .locationAccuracyMeters(10.0).build();

        ResponseEntity<?> response = controller.createVisit(visit, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
        assertThat(response.getHeaders().getFirst("Retry-After")).isEqualTo("5");
    }
}
