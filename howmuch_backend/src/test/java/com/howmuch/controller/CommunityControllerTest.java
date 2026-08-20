package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class CommunityControllerTest {

    @Test
    void rejectsInvalidFeedIdBeforeFirestoreAccess() {
        FirebaseService service = mock(FirebaseService.class);
        CommunityController controller = new CommunityController(service);

        ResponseEntity<?> response = controller.getFeedDetail(
                "folder/feed-1", new MockHttpServletRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(service);
    }

    @Test
    void missingFeedUsesTheStableNotFoundContract() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        CommunityController controller = new CommunityController(service);
        when(service.getCommunityFeedDetail("missing", null)).thenReturn(null);

        ResponseEntity<?> response = controller.getFeedDetail(
                "missing", new MockHttpServletRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody()).isEqualTo(java.util.Map.of(
                "success", false, "message", "게시글을 찾을 수 없습니다."));
    }
}
