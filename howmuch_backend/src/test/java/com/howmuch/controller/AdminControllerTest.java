package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import com.howmuch.service.PublicDataService;
import com.howmuch.service.ReportImageStorage;
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

class AdminControllerTest {

    private FirebaseService firebaseService;
    private ReportImageStorage reportImageStorage;
    private PublicDataService publicDataService;
    private AdminController controller;
    private MockHttpServletRequest request;

    @BeforeEach
    void setUp() {
        firebaseService = mock(FirebaseService.class);
        reportImageStorage = mock(ReportImageStorage.class);
        publicDataService = mock(PublicDataService.class);
        controller = new AdminController(
                firebaseService,
                reportImageStorage,
                publicDataService);
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
    void keepsAdminOperationsClosedWhenTheServerKeyIsMissing() {
        ReflectionTestUtils.setField(controller, "adminKey", "");

        ResponseEntity<?> response = controller.getStoresSnapshot(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        verifyNoInteractions(firebaseService);
    }
}
