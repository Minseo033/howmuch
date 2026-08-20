package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.StoreCoordinates;
import com.howmuch.dto.VisitRequest;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.ReceiptOcrService;
import com.howmuch.service.SimpleRateLimiter;
import com.howmuch.service.DuplicateVisitException;
import com.howmuch.service.DuplicateReceiptException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockMultipartFile;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.times;

import java.util.List;
import java.util.Optional;

class VisitControllerTest {

    private FirebaseService firebaseService;
    private ReceiptOcrService receiptOcrService;
    private SimpleRateLimiter rateLimiter;
    private VisitController controller;
    private MockHttpServletRequest request;

    @BeforeEach
    void setUp() {
        firebaseService = mock(FirebaseService.class);
        receiptOcrService = mock(ReceiptOcrService.class);
        rateLimiter = mock(SimpleRateLimiter.class);
        when(rateLimiter.tryAcquire(anyString(), anyInt(), anyLong())).thenReturn(true);
        controller = new VisitController(firebaseService, receiptOcrService, rateLimiter);
        request = new MockHttpServletRequest();
    }

    @Test
    void requiresAuthenticationBeforeSavingAVisit() {
        ResponseEntity<?> response = controller.createVisit(validRequest(), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rejectsVisitsWithoutVerifiedLocationEvidence() throws Exception {
        authenticate();
        VisitRequest requestBody = validRequest();
        when(firebaseService.findStoreCoordinates(any(), any()))
                .thenReturn(Optional.of(new StoreCoordinates(37.5675, 126.9780)));

        ResponseEntity<?> response = controller.createVisit(requestBody, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verify(firebaseService).findStoreCoordinates(any(), any());
        verify(firebaseService, never()).saveVisit(anyString(), any(), anyLong());
    }

    @Test
    void savesOnlyLocationVerifiedVisits() throws Exception {
        authenticate();
        when(firebaseService.findStoreCoordinates(any(), any()))
                .thenReturn(Optional.of(new StoreCoordinates(37.5665, 126.9780)));
        when(firebaseService.saveVisit(anyString(), any(), anyLong())).thenReturn("visit-1");

        ResponseEntity<?> response = controller.createVisit(validRequest(), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(firebaseService).saveVisit(anyString(), any(), anyLong());
    }

    @Test
    void returnsConflictForADuplicateDailyStoreVisit() throws Exception {
        authenticate();
        when(firebaseService.findStoreCoordinates(any(), any()))
                .thenReturn(Optional.of(new StoreCoordinates(37.5665, 126.9780)));
        when(firebaseService.saveVisit(anyString(), any(), anyLong()))
                .thenThrow(new DuplicateVisitException("오늘 이미 이 매장의 방문 인증을 완료했습니다."));

        ResponseEntity<?> response = controller.createVisit(validRequest(), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void validatesReceiptImageBeforeCallingPaidOcr() throws Exception {
        authenticate();
        MockMultipartFile invalid = new MockMultipartFile(
                "images", "receipt.txt", "text/plain", new byte[]{1, 2, 3});
        when(firebaseService.uploadReportImages("user-1", List.of(invalid)))
                .thenThrow(new IllegalArgumentException("이미지 형식 오류"));

        ResponseEntity<?> response = controller.submitReceiptVerification(
                request, "store-1", "테스트 식당", "김치찌개", 8_000L, List.of(invalid));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(receiptOcrService);
    }

    @Test
    void rateLimitsReceiptOcrBeforeUploading() {
        authenticate();
        when(rateLimiter.tryAcquire(anyString(), anyInt(), anyLong())).thenReturn(false);
        MockMultipartFile image = new MockMultipartFile(
                "images", "receipt.jpg", "image/jpeg",
                new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF});

        ResponseEntity<?> response = controller.submitReceiptVerification(
                request, "store-1", "테스트 식당", "김치찌개", 8_000L, List.of(image));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        verifyNoInteractions(firebaseService, receiptOcrService);
    }

    @Test
    void rejectsKnownReceiptBeforePaidOcrAndUpload() throws Exception {
        authenticate();
        MockMultipartFile image = new MockMultipartFile(
                "images", "receipt.jpg", "image/jpeg",
                new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF});
        when(firebaseService.receiptVerificationExists(anyString())).thenReturn(true);

        ResponseEntity<?> response = controller.submitReceiptVerification(
                request, "store-1", "테스트 식당", "김치찌개", 8_000L, List.of(image));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        verify(firebaseService, never()).uploadReportImages(anyString(), any());
        verifyNoInteractions(receiptOcrService);
    }

    @Test
    void rejectsReceiptsStoredWithTheLegacyPerUserFingerprint() throws Exception {
        authenticate();
        MockMultipartFile image = new MockMultipartFile(
                "images", "receipt.jpg", "image/jpeg",
                new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF});
        when(firebaseService.receiptVerificationExists(anyString()))
                .thenReturn(false, true);

        ResponseEntity<?> response = controller.submitReceiptVerification(
                request, "store-1", "테스트 식당", "김치찌개", 8_000L, List.of(image));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        verify(firebaseService, times(2)).receiptVerificationExists(anyString());
        verify(firebaseService, never()).uploadReportImages(anyString(), any());
        verifyNoInteractions(receiptOcrService);
    }

    @Test
    void receiptFingerprintPreventsTheSameImageAcrossAccounts() {
        byte[] image = new byte[]{1, 2, 3};

        String first = VisitController.receiptFingerprint(image);

        assertThat(first).hasSize(64)
                .isEqualTo(VisitController.receiptFingerprint(image));
        assertThat(VisitController.legacyReceiptFingerprint("user-1", image))
                .isNotEqualTo(VisitController.legacyReceiptFingerprint("user-2", image));
    }

    @Test
    void rejectsANullVisitBodyAsBadRequest() {
        authenticate();

        ResponseEntity<?> response = controller.createVisit(null, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void validatesEstimateInputsBeforeLookingUpStoreData() {
        authenticate();

        ResponseEntity<?> response = controller.estimateSavedAmount(
                " ", "menu", 8_000L, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    private void authenticate() {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
    }

    private VisitRequest validRequest() {
        return VisitRequest.builder()
                .storeName("테스트 식당")
                .storeId("store-test")
                .menu("김치찌개")
                .price(8_000L)
                .verificationMethod("LOCATION")
                .verificationDistanceMeters(25.0)
                .latitude(37.5665)
                .longitude(126.9780)
                .locationAccuracyMeters(10.0)
                .build();
    }
}
