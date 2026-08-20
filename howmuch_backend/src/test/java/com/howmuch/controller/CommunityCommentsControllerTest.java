package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.CommentRequest;
import com.howmuch.dto.CommentResponse;
import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class CommunityCommentsControllerTest {

    private FirebaseService firebaseService;
    private CommunityCommentsController controller;
    private MockHttpServletRequest request;

    @BeforeEach
    void setUp() {
        firebaseService = mock(FirebaseService.class);
        controller = new CommunityCommentsController(firebaseService);
        request = new MockHttpServletRequest();
    }

    @Test
    void hidesRepliesWhenParentCommentIsNotOnAVisibleFeed() throws Exception {
        when(firebaseService.commentBelongsToVisibleFeed("comment-1")).thenReturn(false);

        ResponseEntity<?> response = controller.getReplies("comment-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        verify(firebaseService, never()).getReplies("comment-1", null);
    }

    @Test
    void blocksReplyCreationOnAHiddenFeed() throws Exception {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        when(firebaseService.commentBelongsToVisibleFeed("comment-1")).thenReturn(false);

        ResponseEntity<?> response = controller.createReply(
                "comment-1", CommentRequest.builder().content("답글").build(), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        verify(firebaseService, never()).createReply("comment-1", "user-1", "답글");
    }

    @Test
    void returnsRepliesOnlyAfterVisibilityCheck() throws Exception {
        when(firebaseService.commentBelongsToVisibleFeed("comment-1")).thenReturn(true);
        when(firebaseService.getReplies("comment-1", null)).thenReturn(List.of(
                CommentResponse.builder().id("reply-1").content("답글").build()));

        ResponseEntity<?> response = controller.getReplies("comment-1", request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(firebaseService).getReplies("comment-1", null);
    }

    @Test
    void rejectsInvalidDocumentIdsBeforeFirestoreAccess() {
        ResponseEntity<?> comments = controller.getComments("folder/feed", request);
        ResponseEntity<?> replies = controller.getReplies("folder/comment", request);

        assertThat(comments.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(replies.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rejectsNullCommentBodyInsteadOfReturningServerError() {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");

        ResponseEntity<?> response = controller.createComment("feed-1", null, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(firebaseService);
    }
}
