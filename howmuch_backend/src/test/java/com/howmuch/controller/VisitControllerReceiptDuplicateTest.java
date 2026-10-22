package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.StoreCoordinates;
import com.howmuch.dto.VisitLocationEvidence;
import com.howmuch.service.DuplicateVisitException;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.ReceiptOcrService;
import com.howmuch.service.SimpleRateLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockMultipartFile;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/** 계약 C9: 영수증 제출은 매장을 먼저 확인하고, 같은 날 방문 중복은 409로 응답합니다. */
class VisitControllerReceiptDuplicateTest {
    private final FirebaseService firebaseService = mock(FirebaseService.class);
    private final ReceiptOcrService receiptOcrService = mock(ReceiptOcrService.class);
    private final SimpleRateLimiter rateLimiter = mock(SimpleRateLimiter.class);
    private final VisitController controller = new VisitController(firebaseService, receiptOcrService, rateLimiter);
    private final MockHttpServletRequest request = new MockHttpServletRequest();
    private final MockMultipartFile image = new MockMultipartFile("images", "receipt.jpg", "image/jpeg",
            new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 1});

    @BeforeEach
    void setUp() throws Exception {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        when(firebaseService.findStoreCoordinates(anyString(), anyString()))
                .thenReturn(Optional.of(new StoreCoordinates(37.5, 127.0)));
        when(rateLimiter.tryAcquire(anyString(), anyInt(), anyLong())).thenReturn(true);
        when(firebaseService.uploadReportImages(eq("user-1"), any())).thenReturn(List.of("https://img/r.jpg"));
    }

    @Test
    void unknownStoreIsRejectedBeforeUploadOrPaidOcr() throws Exception {
        ResponseEntity<?> response = controller.submitReceiptVerification(
                request, "store-missing", "없는 식당", "국밥", 7000, List.of(image), 37.5, 127.0, 5.0);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY);
        verify(firebaseService, never()).uploadReportImages(anyString(), any());
        verifyNoInteractions(receiptOcrService);
    }

    @Test
    void receiptIsSavedWithTheCanonicalStoreIdentity() throws Exception {
        when(firebaseService.findVisitableStore("경남식당", "경남식당"))
                .thenReturn(Optional.of(Map.of("storeId", "store_a", "storeName", "경남식당")));
        ReceiptOcrService.Result manual = new ReceiptOcrService.Result(true, 30, 7000, true, true, true,
                null, false, 70, "MANUAL_REVIEW_DATE_MISSING");
        when(receiptOcrService.analyze(any(), eq("경남식당"), eq(7000L))).thenReturn(manual);
        when(firebaseService.saveReceiptVerification(eq("user-1"), eq("store_a"), eq("경남식당"), eq("국밥"),
                eq(7000L), anyString(), any(), eq(manual), eq(new VisitLocationEvidence(0, 5)))).thenReturn("receipt_1");

        ResponseEntity<?> response = controller.submitReceiptVerification(
                request, "경남식당", "경남식당", "국밥", 7000, List.of(image), 37.5, 127.0, 5.0);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(((Map<?, ?>) response.getBody()).get("status")).isEqualTo("PENDING");
        verify(firebaseService, never()).approveReceiptVerification(anyString(), anyString());
        verify(firebaseService).saveReceiptVerification(eq("user-1"), eq("store_a"), eq("경남식당"), eq("국밥"),
                eq(7000L), anyString(), any(), eq(manual), eq(new VisitLocationEvidence(0, 5)));
    }

    @Test
    void withinOneHundredMetersAndAcceptableAccuracyCanSubmitForReview() throws Exception {
        when(firebaseService.findVisitableStore("store_a", "경남식당"))
                .thenReturn(Optional.of(Map.of("storeId", "store_a", "storeName", "경남식당")));
        when(firebaseService.saveReceiptVerification(anyString(), anyString(), anyString(), anyString(),
                anyLong(), anyString(), any(), any(), any())).thenReturn("receipt_1");

        ResponseEntity<?> response = controller.submitReceiptVerification(request, "store_a", "경남식당", "국밥", 7000,
                List.of(image), 37.5008, 127.0, 100.0);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        org.mockito.ArgumentCaptor<VisitLocationEvidence> location = org.mockito.ArgumentCaptor.forClass(VisitLocationEvidence.class);
        verify(firebaseService).saveReceiptVerification(anyString(), anyString(), anyString(), anyString(),
                anyLong(), anyString(), any(), any(), location.capture());
        assertThat(location.getValue().distanceMeters()).isBetween(80.0, 100.0);
        assertThat(location.getValue().accuracyMeters()).isEqualTo(100.0);
        verify(firebaseService, never()).approveReceiptVerification(anyString(), anyString());
    }

    @Test
    void sameDayVisitAtSubmissionReturnsConflictAndCleansUploadedImages() throws Exception {
        when(firebaseService.findVisitableStore("store_a", "경남식당"))
                .thenReturn(Optional.of(Map.of("storeId", "store_a", "storeName", "경남식당")));
        when(firebaseService.saveReceiptVerification(anyString(), anyString(), anyString(), anyString(),
                anyLong(), anyString(), any(), any(), any()))
                .thenThrow(new DuplicateVisitException("같은 날 이 매장의 방문 기록이 이미 있어요."));

        ResponseEntity<?> response = controller.submitReceiptVerification(
                request, "store_a", "경남식당", "국밥", 7000, List.of(image), 37.5, 127.0, 5.0);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        verify(firebaseService).deleteReportImages("user-1", List.of("https://img/r.jpg"));
    }

    @Test
    void automaticApprovalCreatesTheVisitOnlyAfterReceiptSubmission() throws Exception {
        when(firebaseService.findVisitableStore("store_a", "경남식당"))
                .thenReturn(Optional.of(Map.of("storeId", "store_a", "storeName", "경남식당")));
        ReceiptOcrService.Result automatic = new ReceiptOcrService.Result(true, 40, 7000, true, true, true,
                "2026-10-13", true, 100, "AUTO_APPROVED_CANDIDATE");
        when(receiptOcrService.analyze(any(), anyString(), anyLong())).thenReturn(automatic);
        when(firebaseService.saveReceiptVerification(anyString(), anyString(), anyString(), anyString(),
                anyLong(), anyString(), any(), any(), any())).thenReturn("receipt_1");
        when(firebaseService.approveReceiptVerification("receipt_1", "AUTO_OCR"))
                .thenReturn(Map.of("status", "APPROVED", "visitId", "visit-1"));

        ResponseEntity<?> response = controller.submitReceiptVerification(
                request, "store_a", "경남식당", "국밥", 7000, List.of(image), 37.5, 127.0, 5.0);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(((Map<?, ?>) response.getBody()).get("status")).isEqualTo("APPROVED");
        assertThat(((Map<?, ?>) response.getBody()).get("visitId")).isEqualTo("visit-1");
        verify(firebaseService).approveReceiptVerification("receipt_1", "AUTO_OCR");
    }

    @Test
    void committedResubmissionWithSuccessfulOcrDoesNotStartApprovalAfterCleanupCancellation() throws Exception {
        when(firebaseService.findVisitableStore("store_a", "경남식당"))
                .thenReturn(Optional.of(Map.of("storeId", "store_a", "storeName", "경남식당")));
        ReceiptOcrService.Result automatic = new ReceiptOcrService.Result(true, 40, 7000, true, true, true,
                "2026-10-22", true, 100, "AUTO_APPROVED_CANDIDATE");
        assertThat(automatic.shouldAutoApprove()).isTrue();
        when(receiptOcrService.analyze(any(), anyString(), anyString(), anyLong())).thenReturn(automatic);
        when(firebaseService.saveReceiptVerification(anyString(), anyString(), anyString(), anyString(),
                anyLong(), anyString(), any(), eq(automatic), any())).thenAnswer(call -> {
                    Thread.currentThread().interrupt();
                    return "receipt-resubmitted";
                });
        try {
            ResponseEntity<?> response = controller.submitReceiptVerification(
                    request, "store_a", "경남식당", "국밥", 7000, List.of(image), 37.5, 127.0, 5.0);
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
            Map<?, ?> accepted = (Map<?, ?>) response.getBody();
            assertThat(accepted.get("id")).isEqualTo("receipt-resubmitted");
            assertThat(accepted.get("status")).isEqualTo("PENDING");
            assertThat(Thread.currentThread().isInterrupted()).isTrue();
            verify(firebaseService, never()).approveReceiptVerification(anyString(), anyString());
            verify(firebaseService, never()).deleteReportImages(anyString(), any());
        } finally { Thread.interrupted(); }
    }

    @Test
    void cancelledUncommittedSubmissionStillCompensatesUploadsAndRestoresInterrupt() throws Exception {
        when(firebaseService.findVisitableStore("store_a", "경남식당"))
                .thenReturn(Optional.of(Map.of("storeId", "store_a", "storeName", "경남식당")));
        when(firebaseService.saveReceiptVerification(anyString(), anyString(), anyString(), anyString(),
                anyLong(), anyString(), any(), any(), any())).thenAnswer(call -> {
                    Thread.currentThread().interrupt();
                    throw new java.util.concurrent.CancellationException("not committed");
                });
        org.mockito.Mockito.doAnswer(call -> {
            assertThat(Thread.currentThread().isInterrupted()).isFalse();
            return 1;
        }).when(firebaseService).deleteReportImages("user-1", List.of("https://img/r.jpg"));
        try {
            ResponseEntity<?> response = controller.submitReceiptVerification(
                    request, "store_a", "경남식당", "국밥", 7000, List.of(image), 37.5, 127.0, 5.0);
            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
            verify(firebaseService).deleteReportImages("user-1", List.of("https://img/r.jpg"));
            assertThat(Thread.currentThread().isInterrupted()).isTrue();
            verify(firebaseService, never()).approveReceiptVerification(anyString(), anyString());
        } finally { Thread.interrupted(); }
    }

    @Test
    void duplicateFoundDuringAutomaticApprovalIsRejectedInsteadOfCredited() throws Exception {
        when(firebaseService.findVisitableStore("store_a", "경남식당"))
                .thenReturn(Optional.of(Map.of("storeId", "store_a", "storeName", "경남식당")));
        ReceiptOcrService.Result automatic = new ReceiptOcrService.Result(true, 40, 7000, true, true, true,
                "2026-10-01", true, 100, "AUTO_APPROVED_CANDIDATE");
        when(receiptOcrService.analyze(any(), anyString(), anyLong())).thenReturn(automatic);
        when(firebaseService.saveReceiptVerification(anyString(), anyString(), anyString(), anyString(),
                anyLong(), anyString(), any(), any(), any())).thenReturn("receipt_1");
        when(firebaseService.approveReceiptVerification("receipt_1", "AUTO_OCR"))
                .thenThrow(new DuplicateVisitException("같은 날 이 매장의 방문 기록이 이미 있어 영수증을 승인할 수 없어요."));

        ResponseEntity<?> response = controller.submitReceiptVerification(
                request, "store_a", "경남식당", "국밥", 7000, List.of(image), 37.5, 127.0, 5.0);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        verify(firebaseService).rejectReceiptVerification(eq("receipt_1"), anyString(), eq("AUTO_DUPLICATE"));
    }
}

