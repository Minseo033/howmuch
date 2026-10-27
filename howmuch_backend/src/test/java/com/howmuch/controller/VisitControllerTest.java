package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.StoreCoordinates;
import com.howmuch.dto.VisitRequest;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.ReceiptOcrService;
import com.howmuch.service.SimpleRateLimiter;
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
    void deletesOnlyThroughTheAuthenticatedOwnerContract() throws Exception {
        authenticate();

        ResponseEntity<?> response = controller.deleteMyVisit(" visit-1 ", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(firebaseService).deleteOwnedVisit("visit-1", "user-1");
    }

    @Test
    void hidesMissingOrForeignVisitsBehindNotFound() throws Exception {
        authenticate();
        org.mockito.Mockito.doThrow(new java.util.NoSuchElementException("방문 기록을 찾을 수 없습니다."))
                .when(firebaseService).deleteOwnedVisit("visit-2", "user-1");

        ResponseEntity<?> response = controller.deleteMyVisit("visit-2", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void rejectsVisitDeletionWithoutAuthentication() {
        ResponseEntity<?> response = controller.deleteMyVisit("visit-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rejectsLocationOnlyAndForgedReceiptVisitsWithoutAnyWrites() {
        authenticate();
        for (String method : new String[]{"LOCATION", "RECEIPT_OCR", "LOCATION_RECEIPT", ""}) {
            VisitRequest body = validRequest();
            body.setVerificationMethod(method);
            ResponseEntity<?> response = controller.createVisit(body, request);
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
            assertThat(((java.util.Map<?, ?>) response.getBody()).get("code")).isEqualTo("RECEIPT_REQUIRED");
        }
        verifyNoInteractions(firebaseService, receiptOcrService);
    }

    @Test
    void aFreeMenuCannotBypassReceiptVerification() {
        authenticate();
        VisitRequest body = validRequest();
        body.setPrice(0L);
        assertThat(controller.createVisit(body, request).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        verifyNoInteractions(firebaseService, receiptOcrService);
    }

    @Test
    void closedReceiptIsRejectedBeforeImageUploadOrPaidOcr() throws Exception {
        authenticate();
        MockMultipartFile image = new MockMultipartFile("images", "receipt.jpg", "image/jpeg",
                new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF});
        when(firebaseService.isClosedStore("store-1", "테스트 식당")).thenReturn(true);
        assertThat(controller.submitReceiptVerification(request, "store-1", "테스트 식당", "국밥", 6000, List.of(image), 37.5665, 126.9780, 10.0)
                .getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verify(firebaseService, never()).uploadReportImages(anyString(), any());
        verifyNoInteractions(receiptOcrService);
    }

    @Test
    void aReceiptWithoutLocationIsRejectedBeforeUploadOrOcr() {
        authenticate();
        ResponseEntity<?> response = controller.submitReceiptVerification(request, "store-1", "테스트 식당",
                "국밥", 6000L, List.of(receiptImage()), null, null, null);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(((java.util.Map<?, ?>) response.getBody()).get("code")).isEqualTo("LOCATION_REQUIRED");
        verifyNoInteractions(firebaseService, receiptOcrService);
    }

    @Test
    void aReceiptOutsideOneHundredMetersIsRejectedBeforeUploadOrOcr() throws Exception {
        authenticate();
        knownStore();
        ResponseEntity<?> response = controller.submitReceiptVerification(request, "store-1", "테스트 식당",
                "국밥", 6000L, List.of(receiptImage()), 37.5685, 126.9780, 5.0);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verify(firebaseService, never()).uploadReportImages(anyString(), any());
        verifyNoInteractions(receiptOcrService);
    }

    @Test
    void aReceiptWithUnusableGpsAccuracyIsRejected() {
        authenticate();
        for (Double accuracy : new Double[]{null, -1.0, 100.1, Double.NaN}) {
            assertThat(controller.submitReceiptVerification(request, "store-1", "테스트 식당",
                    "국밥", 6000L, List.of(receiptImage()), 37.5665, 126.9780, accuracy).getStatusCode())
                    .isEqualTo(HttpStatus.BAD_REQUEST);
        }
        verifyNoInteractions(firebaseService, receiptOcrService);
    }

    @Test
    void validLocationStillRequiresAReceiptImage() {
        authenticate();
        assertThat(controller.submitReceiptVerification(request, "store-1", "테스트 식당", "국밥", 6000L,
                List.of(), 37.5665, 126.9780, 5.0).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService, receiptOcrService);
    }

    @Test
    void validatesReceiptImageBeforeCallingPaidOcr() throws Exception {
        authenticate();
        MockMultipartFile invalid = new MockMultipartFile(
                "images", "receipt.txt", "text/plain", new byte[]{1, 2, 3});
        knownStore();
        when(firebaseService.uploadReportImages("user-1", List.of(invalid)))
                .thenThrow(new IllegalArgumentException("이미지 형식 오류"));

        ResponseEntity<?> response = controller.submitReceiptVerification(
                request, "store-1", "테스트 식당", "김치찌개", 8_000L, List.of(invalid), 37.5665, 126.9780, 10.0);

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
                request, "store-1", "테스트 식당", "김치찌개", 8_000L, List.of(image), 37.5665, 126.9780, 10.0);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        verifyNoInteractions(firebaseService, receiptOcrService);
    }

    @Test
    void rejectsKnownReceiptBeforePaidOcrAndUpload() throws Exception {
        authenticate();
        MockMultipartFile image = new MockMultipartFile(
                "images", "receipt.jpg", "image/jpeg",
                new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF});
        knownStore();
        when(firebaseService.receiptVerificationExists(anyString())).thenReturn(true);

        ResponseEntity<?> response = controller.submitReceiptVerification(
                request, "store-1", "테스트 식당", "김치찌개", 8_000L, List.of(image), 37.5665, 126.9780, 10.0);

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
        knownStore();
        when(firebaseService.receiptVerificationExists(anyString()))
                .thenReturn(false, true);

        ResponseEntity<?> response = controller.submitReceiptVerification(
                request, "store-1", "테스트 식당", "김치찌개", 8_000L, List.of(image), 37.5665, 126.9780, 10.0);

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
    void missingBodyCannotBypassReceiptVerification() {
        authenticate();

        ResponseEntity<?> response = controller.createVisit(null, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
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

    private MockMultipartFile receiptImage() {
        return new MockMultipartFile("images", "receipt.jpg", "image/jpeg",
                new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF});
    }

    private void knownStore() {
        when(firebaseService.findStoreCoordinates("store-1", "테스트 식당"))
                .thenReturn(Optional.of(new StoreCoordinates(37.5665, 126.9780)));
        when(firebaseService.findVisitableStore("store-1", "테스트 식당"))
                .thenReturn(Optional.of(java.util.Map.of("storeId", "store-1", "storeName", "테스트 식당")));
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
