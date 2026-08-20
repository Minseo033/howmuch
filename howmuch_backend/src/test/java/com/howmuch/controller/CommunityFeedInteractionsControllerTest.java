package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

class CommunityFeedInteractionsControllerTest {

    @Test
    void rejectsInvalidIdsAcrossAllMutationEndpoints() {
        FirebaseService service = mock(FirebaseService.class);
        CommunityFeedInteractionsController controller =
                new CommunityFeedInteractionsController(service);
        MockHttpServletRequest request = new MockHttpServletRequest();

        ResponseEntity<?> like = controller.like("folder/feed", request);
        ResponseEntity<?> unlike = controller.unlike("folder/feed", request);
        ResponseEntity<?> subscribe = controller.subscribe("folder/feed", request);
        ResponseEntity<?> unsubscribe = controller.unsubscribe("folder/feed", request);

        assertThat(like.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(unlike.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(subscribe.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(unsubscribe.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(service);
    }
}
