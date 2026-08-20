package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.CommentRequest;
import com.howmuch.dto.CommentResponse;
import com.howmuch.service.FirebaseService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 커뮤니티 댓글/답글 API 컨트롤러.
 * GET  /api/community/feed/{postId}/comments      댓글 목록
 * POST /api/community/feed/{postId}/comments      댓글 작성
 * GET  /api/community/comments/{commentId}/replies 답글 목록
 * POST /api/community/comments/{commentId}/replies 답글 작성
 */
@Slf4j
@RestController
@RequestMapping("/api/community")
@RequiredArgsConstructor
public class CommunityCommentsController {

    private final FirebaseService firebaseService;

    /** 댓글 목록 조회 */
    @GetMapping("/feed/{postId}/comments")
    public ResponseEntity<?> getComments(@PathVariable String postId,
                                         HttpServletRequest httpRequest) {
        ResponseEntity<?> invalidId = validateDocumentId(postId, "게시글");
        if (invalidId != null) return invalidId;
        String uid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            if (!firebaseService.feedExists(postId)) {
                return ResponseEntity.status(404).body(Map.of(
                        "success", false, "message", "게시글을 찾을 수 없습니다."));
            }
            List<CommentResponse> comments = firebaseService.getComments(postId, uid);
            return ResponseEntity.ok(comments);
        } catch (Exception e) {
            log.error("[CommunityCommentsController] 댓글 목록 조회 오류: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "댓글을 불러오는 중 오류가 발생했습니다."));
        }
    }

    /** 댓글 작성 */
    @PostMapping("/feed/{postId}/comments")
    public ResponseEntity<?> createComment(@PathVariable String postId,
                                           @RequestBody CommentRequest request,
                                           HttpServletRequest httpRequest) {
        ResponseEntity<?> invalidId = validateDocumentId(postId, "게시글");
        if (invalidId != null) return invalidId;
        String uid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            if (uid == null || uid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false, "message", "로그인이 필요합니다."));
            }
            if (request == null || request.getContent() == null || request.getContent().isBlank()) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false, "message", "댓글 내용을 입력해주세요."));
            }
            if (request.getContent().length() > 1000) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false, "message", "댓글은 1000자 이내로 입력해주세요."));
            }
            if (!firebaseService.feedExists(postId)) {
                return ResponseEntity.status(404).body(Map.of(
                        "success", false, "message", "게시글을 찾을 수 없습니다."));
            }
            CommentResponse created = firebaseService.createComment(postId, uid, request.getContent().trim());
            return ResponseEntity.ok(created);
        } catch (Exception e) {
            log.error("[CommunityCommentsController] 댓글 작성 오류: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "댓글 등록 중 오류가 발생했습니다."));
        }
    }

    /** 답글 목록 조회 */
    @GetMapping("/comments/{commentId}/replies")
    public ResponseEntity<?> getReplies(@PathVariable String commentId,
                                        HttpServletRequest httpRequest) {
        ResponseEntity<?> invalidId = validateDocumentId(commentId, "댓글");
        if (invalidId != null) return invalidId;
        String uid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            if (!firebaseService.commentBelongsToVisibleFeed(commentId)) {
                return ResponseEntity.status(404).body(Map.of(
                        "success", false, "message", "댓글을 찾을 수 없습니다."));
            }
            List<CommentResponse> replies = firebaseService.getReplies(commentId, uid);
            return ResponseEntity.ok(replies);
        } catch (Exception e) {
            log.error("[CommunityCommentsController] 답글 목록 조회 오류: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "답글을 불러오는 중 오류가 발생했습니다."));
        }
    }

    /** 답글 작성 */
    @PostMapping("/comments/{commentId}/replies")
    public ResponseEntity<?> createReply(@PathVariable String commentId,
                                         @RequestBody CommentRequest request,
                                         HttpServletRequest httpRequest) {
        ResponseEntity<?> invalidId = validateDocumentId(commentId, "댓글");
        if (invalidId != null) return invalidId;
        String uid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            if (uid == null || uid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false, "message", "로그인이 필요합니다."));
            }
            if (request == null || request.getContent() == null || request.getContent().isBlank()) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false, "message", "답글 내용을 입력해주세요."));
            }
            if (request.getContent().length() > 1000) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false, "message", "답글은 1000자 이내로 입력해주세요."));
            }
            if (!firebaseService.commentBelongsToVisibleFeed(commentId)) {
                return ResponseEntity.status(404).body(Map.of(
                        "success", false, "message", "댓글을 찾을 수 없습니다."));
            }
            CommentResponse created = firebaseService.createReply(commentId, uid, request.getContent().trim());
            if (created == null) {
                return ResponseEntity.status(404).body(Map.of(
                        "success", false, "message", "댓글을 찾을 수 없습니다."));
            }
            return ResponseEntity.ok(created);
        } catch (Exception e) {
            log.error("[CommunityCommentsController] 답글 작성 오류: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "답글 등록 중 오류가 발생했습니다."));
        }
    }

    private ResponseEntity<?> validateDocumentId(String value, String label) {
        if (value == null || value.isBlank()
                || value.length() > 512 || value.contains("/")) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", label + " ID가 올바르지 않습니다."));
        }
        return null;
    }
}
