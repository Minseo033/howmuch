package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.ReceiptOcrService;
import com.howmuch.service.SimpleRateLimiter;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockMultipartFile;

import java.util.Optional;
import java.util.List;

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
    void receiptSubmissionIsRetryableWhileTheCatalogWarmsUp() {
        VisitController controller = new VisitController(firebaseService, mock(ReceiptOcrService.class),
                new SimpleRateLimiter());
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        when(firebaseService.findVisitableStore(any(), any())).thenReturn(Optional.empty());
        when(firebaseService.isStoreCatalogWarmingUp()).thenReturn(true);
        MockMultipartFile image = new MockMultipartFile("images", "receipt.jpg", "image/jpeg",
                new byte[]{(byte) 0xff, (byte) 0xd8, (byte) 0xff});
        ResponseEntity<?> response = controller.submitReceiptVerification(request, "store_a", "국밥집", "국밥", 8000L,
                List.of(image), 37.5, 127.0, 5.0);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
        assertThat(response.getHeaders().getFirst("Retry-After")).isEqualTo("5");
    }
}
