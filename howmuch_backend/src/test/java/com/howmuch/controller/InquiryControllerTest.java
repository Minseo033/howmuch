package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.InquiryRequest;
import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

class InquiryControllerTest {

    @Test
    void requiresAuthenticationBeforeWritingInquiry() {
        FirebaseService service = mock(FirebaseService.class);
        InquiryController controller = new InquiryController(service);

        ResponseEntity<?> response = controller.createInquiry(
                InquiryRequest.builder().title("문의").content("내용").build(),
                new MockHttpServletRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(service);
    }

    @Test
    void rejectsAnOversizedCategoryBeforeWritingInquiry() {
        FirebaseService service = mock(FirebaseService.class);
        InquiryController controller = new InquiryController(service);
        MockHttpServletRequest httpRequest = new MockHttpServletRequest();
        httpRequest.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        InquiryRequest request = InquiryRequest.builder()
                .title("문의")
                .content("내용")
                .category("가".repeat(51))
                .build();

        ResponseEntity<?> response = controller.createInquiry(request, httpRequest);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(service);
    }

    @Test
    void rejectsMoreThanThreeImagesBeforeWritingInquiry() {
        FirebaseService service = mock(FirebaseService.class);
        InquiryController controller = new InquiryController(service);
        MockHttpServletRequest httpRequest = new MockHttpServletRequest();
        httpRequest.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        InquiryRequest request = InquiryRequest.builder()
                .title("문의")
                .content("내용")
                .imageUrls(List.of("a", "b", "c", "d"))
                .build();

        ResponseEntity<?> response = controller.createInquiry(request, httpRequest);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(service);
    }
}
