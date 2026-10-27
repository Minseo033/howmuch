package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import com.howmuch.service.PublicDataService;
import com.howmuch.service.ReportImageStorage;
import com.howmuch.service.ReceiptOcrEvidenceException;
import com.howmuch.service.ReceiptVerificationNotFoundException;
import com.howmuch.service.SimpleRateLimiter;
import com.howmuch.service.SessionTokenService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
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
    void updatesAReportIndustryWithoutChangingItsStatus() throws Exception {
        ResponseEntity<?> response = controller.updateReportIndustry(
                "report-1", Map.of("industry", "교통·주차 · 주차장"), request);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(firebaseService).updateReportIndustryAsAdmin("report-1", "교통·주차 · 주차장");
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
    void deletesAnInquiryThroughTheAdminContract() throws Exception {
        Map<String, Object> deletion = Map.of(
                "success", true,
                "id", "inquiry-1",
                "deletedImages", 1);
        when(firebaseService.deleteInquiryAsAdmin("inquiry-1")).thenReturn(deletion);

        ResponseEntity<?> response = controller.deleteInquiry("inquiry-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(deletion);
        verify(firebaseService).deleteInquiryAsAdmin("inquiry-1");
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
    void revokesAllSessionsBeforeAnAdminDeletesAnAccount() throws Exception {
        SessionTokenService sessions = mock(SessionTokenService.class);
        controller = new AdminController(firebaseService, reportImageStorage, publicDataService,
                rateLimiter, sessions);
        ReflectionTestUtils.setField(controller, "adminKey", "admin-secret");
        when(firebaseService.deleteUser("user-1")).thenReturn(Map.of("uid", "user-1"));

        ResponseEntity<?> response = controller.deleteUser("user-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        org.mockito.InOrder order = inOrder(sessions, firebaseService);
        order.verify(sessions).invalidateAllForUid("user-1");
        order.verify(firebaseService).deleteUser("user-1");
    }

    @Test
    void doesNotDeleteAnAccountWhenAdminSessionRevocationCannotBePersisted() {
        SessionTokenService sessions = mock(SessionTokenService.class);
        controller = new AdminController(firebaseService, reportImageStorage, publicDataService,
                rateLimiter, sessions);
        ReflectionTestUtils.setField(controller, "adminKey", "admin-secret");
        doThrow(new RuntimeException("Firestore unavailable"))
                .when(sessions).invalidateAllForUid("user-1");

        ResponseEntity<?> response = controller.deleteUser("user-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        verify(sessions).invalidateAllForUid("user-1");
        verifyNoInteractions(firebaseService);
    }

    @Test
    void returnsUnprocessableEntityWhenReceiptOcrEvidenceIsUnavailable() throws Exception {
        when(firebaseService.approveReceiptVerification("receipt-1", "ADMIN"))
                .thenThrow(new ReceiptOcrEvidenceException("OCR 판독이 완료되지 않았습니다."));

        ResponseEntity<?> response = controller.approveReceipt("receipt-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY);
        verify(firebaseService).approveReceiptVerification("receipt-1", "ADMIN");
    }

    @Test
    void returnsNotFoundWhenReceiptVerificationDoesNotExist() throws Exception {
        when(firebaseService.approveReceiptVerification("receipt-missing", "ADMIN"))
                .thenThrow(new ReceiptVerificationNotFoundException("영수증 인증을 찾을 수 없습니다."));

        ResponseEntity<?> response = controller.approveReceipt("receipt-missing", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
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
                "missing-user", "알림", "내용", "admin", null))
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
                "missing-user", "알림", "내용", "admin", null);
    }

    @Test
    void publishesANoticeThroughTheSeparateAdminContract() throws Exception {
        Map<String, Object> published = Map.of("sent", 3, "broadcast", true);
        when(firebaseService.publishAdminNotice("서비스 안내", "새 기능을 확인해주세요.", null))
                .thenReturn(published);

        ResponseEntity<?> response = controller.publishNotice(
                Map.of("title", " 서비스 안내 ", "body", " 새 기능을 확인해주세요. "),
                request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(published);
        verify(firebaseService).publishAdminNotice("서비스 안내", "새 기능을 확인해주세요.", null);
    }

    @Test
    void rejectsBlankNoticeBeforePublishing() {
        ResponseEntity<?> response = controller.publishNotice(
                Map.of("title", " ", "body", "내용"), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    /** QA 2026-10-07 #57: 함께 지운 답글 ID를 돌려줘 관리자 목록이 새로고침 없이 정리됩니다. */
    @Test
    @SuppressWarnings("unchecked")
    void commentDeletionReportsTheRepliesRemovedWithIt() throws Exception {
        when(firebaseService.deleteComment("comment-1")).thenReturn(List.of("comment-1", "reply-1"));

        ResponseEntity<?> response = controller.deleteComment("comment-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat((Map<String, Object>) response.getBody()).containsEntry("success", true)
                .containsEntry("deletedIds", List.of("comment-1", "reply-1"));
    }

    /** QA 2026-10-07 #3: 회수는 관리자 키가 있어야 하고, 없는 공지·잘못된 ID는 서버 오류가 아니라 요청 오류로 답합니다. */
    @Test
    void recallingSentMessagesNeedsTheAdminKeyAndMapsMissingOrMalformedIds() throws Exception {
        String id = "2026-09-10T06:00:00.123456Z~0123456789abcdef";
        when(firebaseService.recallAdminMessage(FirebaseService.AdminMessageKind.NOTICE, id))
                .thenReturn(Map.of("success", true, "id", id, "deleted", 7));
        when(firebaseService.recallAdminMessage(FirebaseService.AdminMessageKind.GENERAL, id))
                .thenThrow(new NoSuchElementException("이미 회수했거나 찾을 수 없는 공지·알림입니다."));
        when(firebaseService.recallAdminMessage(FirebaseService.AdminMessageKind.NOTICE, "not-an-id"))
                .thenThrow(new IllegalArgumentException("회수할 공지·알림 ID 형식이 올바르지 않습니다."));

        assertThat(controller.recallNotice(id, request).getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(controller.recallNotification(id, request).getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(controller.recallNotice("not-an-id", request).getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        MockHttpServletRequest anonymous = new MockHttpServletRequest();
        assertThat(controller.recallNotice(id, anonymous).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(controller.getNotices(anonymous).getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verify(firebaseService, org.mockito.Mockito.times(1))
                .recallAdminMessage(FirebaseService.AdminMessageKind.NOTICE, id);
    }
}
