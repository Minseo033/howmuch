package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/** 계약 C3: POST /api/notifications/read-all */
class NotificationControllerReadAllTest {
    private final FirebaseService firebaseService = mock(FirebaseService.class);
    private final NotificationController controller = new NotificationController(firebaseService);

    @Test
    void requiresAnAuthenticatedUser() {
        ResponseEntity<?> response = controller.markAllAsRead(new MockHttpServletRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void returnsTheNumberOfUpdatedNotifications() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        when(firebaseService.markAllNotificationsAsRead("user-1")).thenReturn(3);

        ResponseEntity<?> response = controller.markAllAsRead(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(Map.of("success", true, "updated", 3));
    }
}

