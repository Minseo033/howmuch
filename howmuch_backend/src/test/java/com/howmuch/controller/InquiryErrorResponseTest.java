package com.howmuch.controller;

import com.howmuch.config.ClientIpResolver;
import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.InquiryRequest;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.PublicDataService;
import com.howmuch.service.ReportImageStorage;
import com.howmuch.service.SessionTokenService;
import com.howmuch.service.SimpleRateLimiter;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** WEB-ADM-15(문의 삭제 안내)·BE-CORE-21(잘못된 첨부 주소는 400) */
class InquiryErrorResponseTest {
    private final FirebaseService firebaseService = mock(FirebaseService.class);

    @Test
    void ownerlessAttachmentIsAConflictNotAStorageOutage() throws Exception {
        SimpleRateLimiter rateLimiter = mock(SimpleRateLimiter.class);
        when(rateLimiter.tryAcquire(anyString(), anyInt(), anyLong())).thenReturn(true);
        AdminController controller = new AdminController(firebaseService, mock(ReportImageStorage.class),
                mock(PublicDataService.class), rateLimiter, mock(SessionTokenService.class),
                new ClientIpResolver("127.0.0.1/32,::1/128"));
        ReflectionTestUtils.setField(controller, "adminKey", "test-admin-key");
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("X-Admin-Key", "test-admin-key");
        when(firebaseService.deleteInquiryAsAdmin("legacy"))
                .thenThrow(new FirebaseService.InquiryImageOwnerUnknownException("첨부 이미지 소유자 정보를 확인할 수 없습니다."));
        when(firebaseService.deleteInquiryAsAdmin("storage-down"))
                .thenThrow(new IllegalStateException("storage unavailable"));

        ResponseEntity<?> ownerless = controller.deleteInquiry("legacy", request);
        ResponseEntity<?> storageDown = controller.deleteInquiry("storage-down", request);

        assertThat(ownerless.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(String.valueOf(((java.util.Map<?, ?>) ownerless.getBody()).get("message"))).contains("작성자 정보");
        assertThat(storageDown.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
    }

    @Test
    void foreignOrMalformedAttachmentUrlIsABadRequest() throws Exception {
        InquiryController controller = new InquiryController(firebaseService);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        when(firebaseService.createInquiry(eq("user-1"), any()))
                .thenThrow(new IllegalArgumentException("유효하지 않은 제보 이미지 URL이 포함되어 있습니다."));

        ResponseEntity<?> response = controller.createInquiry(InquiryRequest.builder().title("문의").content("내용")
                .imageUrls(List.of("https://evil.example/x.jpg")).build(), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }
}

