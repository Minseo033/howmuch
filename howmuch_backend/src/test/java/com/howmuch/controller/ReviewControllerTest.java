package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.ReviewRequest;
import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class ReviewControllerTest {

    private FirebaseService firebaseService;
    private ReviewController controller;
    private MockHttpServletRequest httpRequest;

    @BeforeEach
    void setUp() {
        firebaseService = mock(FirebaseService.class);
        controller = new ReviewController(firebaseService);
        httpRequest = new MockHttpServletRequest();
    }

    @Test
    void rejectsReviewWhenAuthenticatedUidIsMissing() {
        ResponseEntity<?> response = controller.createReview(httpRequest, validRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rejectsMyReviewsWhenAuthenticatedUidIsMissing() {
        ResponseEntity<?> response = controller.getMyReviews(httpRequest);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rejectsBlankOrOversizedStoreIdBeforeQueryingReviews() {
        ResponseEntity<?> blank = controller.getReviews("   ");
        ResponseEntity<?> oversized = controller.getReviews("s".repeat(201));

        assertThat(blank.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(oversized.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rejectsWhitespaceContentAndMenuWithoutCreatingDefaults() {
        authenticate();
        ReviewRequest request = validRequest();
        request.setMenu("   ");
        request.setContent("\n  ");

        ResponseEntity<?> response = controller.createReview(httpRequest, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rejectsMissingOrOutOfRangePrice() {
        authenticate();
        ReviewRequest request = validRequest();
        request.setPrice(10_000_001);

        ResponseEntity<?> response = controller.createReview(httpRequest, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void trimsValidatedReviewBeforeSaving() throws Exception {
        authenticate();
        ReviewRequest request = validRequest();
        request.setStoreId("  테스트 식당  ");
        request.setStoreName("  테스트 식당  ");
        request.setAuthorName("   ");
        request.setMenu("  김치찌개  ");
        request.setContent("  가격이 합리적이에요.  ");
        when(firebaseService.saveReview(anyString(), any())).thenReturn("review-1");

        ResponseEntity<?> response = controller.createReview(httpRequest, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        ArgumentCaptor<ReviewRequest> captor = ArgumentCaptor.forClass(ReviewRequest.class);
        verify(firebaseService).saveReview(anyString(), captor.capture());
        ReviewRequest saved = captor.getValue();
        assertThat(saved.getStoreId()).isEqualTo("테스트 식당");
        assertThat(saved.getStoreName()).isEqualTo("테스트 식당");
        assertThat(saved.getAuthorName()).isEqualTo("사용자");
        assertThat(saved.getMenu()).isEqualTo("김치찌개");
        assertThat(saved.getContent()).isEqualTo("가격이 합리적이에요.");
        assertThat(saved.getPrice()).isEqualTo(8_000);
    }

    private void authenticate() {
        httpRequest.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
    }

    private ReviewRequest validRequest() {
        return ReviewRequest.builder()
                .storeId("테스트 식당")
                .storeName("테스트 식당")
                .authorName("테스터")
                .menu("김치찌개")
                .price(8_000)
                .content("가격이 합리적이에요.")
                .stars(5)
                .build();
    }
}
