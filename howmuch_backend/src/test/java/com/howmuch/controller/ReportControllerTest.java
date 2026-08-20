package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.UserReportRequest;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.KakaoLocalService;
import com.howmuch.service.SimpleRateLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.Map;
import java.util.NoSuchElementException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class ReportControllerTest {

    private FirebaseService firebaseService;
    private ReportController controller;
    private MockHttpServletRequest request;

    @BeforeEach
    void setUp() {
        firebaseService = mock(FirebaseService.class);
        controller = new ReportController(
                firebaseService,
                mock(KakaoLocalService.class),
                mock(SimpleRateLimiter.class));
        request = new MockHttpServletRequest();
    }

    @Test
    void requiresAuthenticationToDeleteAReport() {
        ResponseEntity<?> response = controller.deleteStoreReport("report-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void returnsTheDeletionResultForTheAuthenticatedOwner() throws Exception {
        authenticate("user-1");
        when(firebaseService.deleteUserReport("report-1", "user-1"))
                .thenReturn(Map.of(
                        "success", true,
                        "id", "report-1",
                        "deletedImages", 2));

        ResponseEntity<?> response = controller.deleteStoreReport("report-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(Map.of(
                "success", true,
                "id", "report-1",
                "deletedImages", 2));
        verify(firebaseService).deleteUserReport("report-1", "user-1");
    }

    @Test
    void returnsForbiddenWhenTheAuthenticatedUserDoesNotOwnTheReport() throws Exception {
        authenticate("user-2");
        when(firebaseService.deleteUserReport("report-1", "user-2"))
                .thenThrow(new SecurityException("본인의 제보만 삭제할 수 있습니다."));

        ResponseEntity<?> response = controller.deleteStoreReport("report-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void returnsNotFoundForAMissingReport() throws Exception {
        authenticate("user-1");
        when(firebaseService.deleteUserReport("missing", "user-1"))
                .thenThrow(new NoSuchElementException("제보를 찾을 수 없습니다."));

        ResponseEntity<?> response = controller.deleteStoreReport("missing", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void returnsServiceUnavailableWithoutConfiguredImageStorage() throws Exception {
        authenticate("user-1");
        when(firebaseService.deleteUserReport("report-1", "user-1"))
                .thenThrow(new IllegalStateException("storage unavailable"));

        ResponseEntity<?> response = controller.deleteStoreReport("report-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
    }

    @Test
    void rejectsANullReportWithoutCallingDependencies() {
        authenticate("user-1");

        ResponseEntity<?> response = controller.submitStoreReport(request, null);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rejectsInvalidDocumentIdsBeforeAccessingFirestore() {
        authenticate("user-1");

        ResponseEntity<?> update = controller.updateStoreReport(
                "folder/report-1", request, validReport());
        ResponseEntity<?> delete = controller.deleteStoreReport("folder/report-1", request);

        assertThat(update.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(delete.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void trimsReportFieldsBeforeSaving() throws Exception {
        authenticate("user-1");
        UserReportRequest report = validReport();
        report.setStoreName("  실제 매장  ");
        report.setAddress("  서울시 중구  ");
        when(firebaseService.saveUserReport(report)).thenReturn("report-1");

        ResponseEntity<?> response = controller.submitStoreReport(request, report);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(report.getStoreName()).isEqualTo("실제 매장");
        assertThat(report.getAddress()).isEqualTo("서울시 중구");
        assertThat(report.getReporterId()).isEqualTo("user-1");
        verify(firebaseService).saveUserReport(report);
    }

    @Test
    void rejectsOversizedMenuTextBeforeSaving() {
        authenticate("user-1");
        UserReportRequest report = validReport();
        report.setMenu1("가".repeat(101));

        ResponseEntity<?> response = controller.submitStoreReport(request, report);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void requiresAuthenticationForMyReportsEvenWhenCalledWithoutTheFilter() {
        ResponseEntity<?> response = controller.getMyReports(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(firebaseService);
    }

    private UserReportRequest validReport() {
        return UserReportRequest.builder()
                .storeName("실제 매장")
                .address("서울시 중구")
                .build();
    }

    private void authenticate(String uid) {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, uid);
    }
}
