package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import com.howmuch.service.PublicDataService;
import com.howmuch.service.ReportImageStorage;
import com.howmuch.service.SimpleRateLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;

class AdminControllerTest {

    private FirebaseService firebaseService;
    private ReportImageStorage reportImageStorage;
    private PublicDataService publicDataService;
    private SimpleRateLimiter rateLimiter;
    private AdminController controller;
    private MockHttpServletRequest request;

    @BeforeEach
    void setUp() {
        firebaseService = mock(FirebaseService.class);
        reportImageStorage = mock(ReportImageStorage.class);
        publicDataService = mock(PublicDataService.class);
        rateLimiter = mock(SimpleRateLimiter.class);
        when(rateLimiter.tryAcquire(anyString(), anyInt(), anyLong())).thenReturn(true);
        controller = new AdminController(
                firebaseService,
                reportImageStorage,
                publicDataService,
                rateLimiter);
        ReflectionTestUtils.setField(controller, "adminKey", "admin-secret");
        request = new MockHttpServletRequest();
        request.addHeader("X-Admin-Key", "admin-secret");
    }

    @Test
    void deletesAReportThroughTheAdminContract() throws Exception {
        Map<String, Object> deletion = Map.of(
                "success", true,
                "id", "report-1",
                "deletedImages", 2);
        when(firebaseService.deleteReportAsAdmin("report-1")).thenReturn(deletion);

        ResponseEntity<?> response = controller.deleteReport("report-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(deletion);
        verify(firebaseService).deleteReportAsAdmin("report-1");
    }

    @Test
    void returnsTheSanitizedStorageUsage() throws Exception {
        Map<String, Object> usage = Map.of(
                "plan", "Free",
                "credits", Map.of("used_percent", 12.5));
        when(reportImageStorage.getUsage()).thenReturn(usage);

        ResponseEntity<?> response = controller.getReportImageStorageUsage(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(usage);
    }

    @Test
    void startsOnlyOnePublicDataSynchronization() {
        when(publicDataService.syncAllPublicDataInBackground()).thenReturn(true, false);

        ResponseEntity<?> accepted = controller.syncPublicData(request);
        ResponseEntity<?> conflict = controller.syncPublicData(request);

        assertThat(accepted.getStatusCode()).isEqualTo(HttpStatus.ACCEPTED);
        assertThat(conflict.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void savesAnInquiryAnswerThroughTheAdminContract() throws Exception {
        Map<String, Object> answered = Map.of(
                "success", true,
                "id", "inquiry-1",
                "status", "ANSWERED");
        when(firebaseService.answerInquiry("inquiry-1", "확인 후 수정하겠습니다."))
                .thenReturn(answered);

        ResponseEntity<?> response = controller.answerInquiry(
                "inquiry-1",
                Map.of("answer", "확인 후 수정하겠습니다."),
                request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(answered);
        verify(firebaseService).answerInquiry("inquiry-1", "확인 후 수정하겠습니다.");
    }

    @Test
    void rejectsBlankInquiryAnswersBeforeCallingTheService() {
        ResponseEntity<?> response = controller.answerInquiry(
                "inquiry-1",
                Map.of("answer", "  "),
                request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void keepsAdminOperationsClosedWhenTheServerKeyIsMissing() {
        ReflectionTestUtils.setField(controller, "adminKey", "");

        ResponseEntity<?> response = controller.getStoresSnapshot(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rateLimitsRepeatedInvalidAdminKeysWithoutBlockingARequestThread() {
        request.removeHeader("X-Admin-Key");
        request.addHeader("X-Admin-Key", "wrong-key");
        when(rateLimiter.tryAcquire(anyString(), anyInt(), anyLong())).thenReturn(false);

        ResponseEntity<?> response = controller.getStoresSnapshot(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rateLimitKeyUsesTheProxyAppendedAddressInsteadOfSpoofedForwardingInput() {
        request.removeHeader("X-Admin-Key");
        request.addHeader("X-Admin-Key", "wrong-key");
        request.addHeader("X-Forwarded-For", "attacker-controlled, 198.51.100.7");

        controller.getStoresSnapshot(request);

        verify(rateLimiter).tryAcquire("admin-auth:198.51.100.7", 10, 5 * 60_000L);
    }

    @Test
    void rejectsUnknownListStatusBeforeQueryingFirestore() {
        ResponseEntity<?> reports = controller.getReports("BROKEN", request);
        ResponseEntity<?> receipts = controller.getReceiptVerifications("BROKEN", request);

        assertThat(reports.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(receipts.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rejectsInvalidInquiryIdsBeforeWritingAnAnswer() {
        ResponseEntity<?> response = controller.answerInquiry(
                "folder/inquiry-1",
                Map.of("answer", "확인했습니다."),
                request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rejectsInvalidNotificationTargetsBeforeBroadcasting() {
        ResponseEntity<?> response = controller.sendNotification(
                Map.of(
                        "audience", "USER",
                        "title", "알림",
                        "body", "내용",
                        "targetUid", "folder/user-1"),
                request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void refusesAmbiguousNotificationAudienceInsteadOfBroadcasting() {
        ResponseEntity<?> response = controller.sendNotification(
                Map.of("title", "알림", "body", "내용"), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void returnsNotFoundWhenTheNotificationTargetDoesNotExist() throws Exception {
        when(firebaseService.sendAdminNotification(
                "missing-user", "알림", "내용", "admin"))
                .thenThrow(new IllegalArgumentException("대상 회원을 찾을 수 없습니다."));

        ResponseEntity<?> response = controller.sendNotification(
                Map.of(
                        "audience", "USER",
                        "title", " 알림 ",
                        "body", " 내용 ",
                        "type", " admin ",
                        "targetUid", "missing-user"),
                request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody()).isEqualTo(Map.of(
                "success", false,
                "message", "대상 회원을 찾을 수 없습니다."));
        verify(firebaseService).sendAdminNotification(
                "missing-user", "알림", "내용", "admin");
    }
}
