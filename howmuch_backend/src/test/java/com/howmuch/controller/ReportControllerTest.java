package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
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

    private void authenticate(String uid) {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, uid);
    }
}
