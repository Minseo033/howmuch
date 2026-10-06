package com.howmuch.controller;

import com.howmuch.config.ClientIpResolver;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.PublicDataService;
import com.howmuch.service.ReportImageStorage;
import com.howmuch.service.SessionTokenService;
import com.howmuch.service.SimpleRateLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/** WEB-ADM-2: 관리자 알림·공지 API는 선택적 requestId를 받아 서비스에 넘깁니다. */
class AdminControllerRequestIdTest {
    private final FirebaseService firebaseService = mock(FirebaseService.class);
    private final SimpleRateLimiter rateLimiter = mock(SimpleRateLimiter.class);
    private AdminController controller;
    private final MockHttpServletRequest request = new MockHttpServletRequest();

    @BeforeEach
    void setUp() {
        controller = new AdminController(firebaseService, mock(ReportImageStorage.class),
                mock(PublicDataService.class), rateLimiter, mock(SessionTokenService.class),
                new ClientIpResolver("127.0.0.1/32,::1/128"));
        ReflectionTestUtils.setField(controller, "adminKey", "test-admin-key");
        when(rateLimiter.tryAcquire(anyString(), anyInt(), anyLong())).thenReturn(true);
        request.addHeader("X-Admin-Key", "test-admin-key");
    }

    @Test
    void passesTheRequestIdForIdempotentBroadcasts() throws Exception {
        when(firebaseService.sendAdminNotification(null, "알림", "내용", null, "req-20261006-a"))
                .thenReturn(Map.of("sent", 0, "skipped", 3, "broadcast", true));

        ResponseEntity<?> response = controller.sendNotification(Map.of("audience", "ALL", "title", "알림",
                "body", "내용", "requestId", " req-20261006-a "), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(firebaseService).sendAdminNotification(null, "알림", "내용", null, "req-20261006-a");
    }

    @Test
    void rejectsMalformedRequestIds() {
        ResponseEntity<?> notification = controller.sendNotification(Map.of("audience", "ALL", "title", "알림",
                "body", "내용", "requestId", "../../x"), request);
        ResponseEntity<?> notice = controller.publishNotice(Map.of("title", "공지", "body", "내용",
                "requestId", "short"), request);

        assertThat(notification.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(notice.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }
}

