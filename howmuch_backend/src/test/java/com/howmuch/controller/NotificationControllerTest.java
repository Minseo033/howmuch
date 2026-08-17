package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.DeviceTokenRequest;
import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

class NotificationControllerTest {

    @Test
    void registersTheAuthenticatedUsersDeviceToken() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        NotificationController controller = new NotificationController(service);
        MockHttpServletRequest request = authenticatedRequest();

        ResponseEntity<?> response = controller.registerDevice(
                new DeviceTokenRequest("token-1", "android"), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(service).registerDeviceToken("user-1", "token-1", "android");
    }

    @Test
    void doesNotRegisterAnUnauthenticatedDeviceToken() {
        FirebaseService service = mock(FirebaseService.class);
        NotificationController controller = new NotificationController(service);

        ResponseEntity<?> response = controller.registerDevice(
                new DeviceTokenRequest("token-1", "android"), new MockHttpServletRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(service);
    }

    @Test
    void unregistersOnlyTheAuthenticatedUsersCurrentDevice() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        NotificationController controller = new NotificationController(service);

        ResponseEntity<?> response = controller.unregisterDevice(
                new DeviceTokenRequest("token-1", "ios"), authenticatedRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(service).unregisterDeviceToken("user-1", "token-1");
    }

    private MockHttpServletRequest authenticatedRequest() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        return request;
    }
}
