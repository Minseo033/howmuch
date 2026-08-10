package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.service.FirebaseService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 커뮤니티 게시글 좋아요/알림 구독 API 컨트롤러.
 * POST   /api/community/feed/{postId}/like         좋아요 추가
 * DELETE /api/community/feed/{postId}/like         좋아요 취소
 * POST   /api/community/feed/{postId}/notification 알림 구독
 * DELETE /api/community/feed/{postId}/notification 알림 구독 해제
 */
@Slf4j
@RestController
@RequestMapping("/api/community/feed")
@RequiredArgsConstructor
public class CommunityFeedInteractionsController {

    private final FirebaseService firebaseService;

    /** 좋아요 추가 → 최신 likes/likedByMe 반환 */
    @PostMapping("/{postId}/like")
    public ResponseEntity<?> like(@PathVariable String postId,
                                  HttpServletRequest httpRequest) {
        String uid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            if (uid == null || uid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false, "message", "로그인이 필요합니다."));
            }
            if (!firebaseService.feedExists(postId)) {
                return ResponseEntity.status(404).body(Map.of(
                        "success", false, "message", "게시글을 찾을 수 없습니다."));
            }
            return ResponseEntity.ok(firebaseService.likeFeed(postId, uid));
        } catch (Exception e) {
            log.error("[CommunityFeedInteractionsController] 좋아요 추가 오류: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "좋아요 처리 중 오류가 발생했습니다."));
        }
    }

    /** 좋아요 취소 → 최신 likes/likedByMe 반환 */
    @DeleteMapping("/{postId}/like")
    public ResponseEntity<?> unlike(@PathVariable String postId,
                                    HttpServletRequest httpRequest) {
        String uid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            if (uid == null || uid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false, "message", "로그인이 필요합니다."));
            }
            if (!firebaseService.feedExists(postId)) {
                return ResponseEntity.status(404).body(Map.of(
                        "success", false, "message", "게시글을 찾을 수 없습니다."));
            }
            return ResponseEntity.ok(firebaseService.unlikeFeed(postId, uid));
        } catch (Exception e) {
            log.error("[CommunityFeedInteractionsController] 좋아요 취소 오류: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "좋아요 취소 중 오류가 발생했습니다."));
        }
    }

    /** 알림 구독 → notificationEnabled 반환 */
    @PostMapping("/{postId}/notification")
    public ResponseEntity<?> subscribe(@PathVariable String postId,
                                       HttpServletRequest httpRequest) {
        String uid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            if (uid == null || uid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false, "message", "로그인이 필요합니다."));
            }
            if (!firebaseService.feedExists(postId)) {
                return ResponseEntity.status(404).body(Map.of(
                        "success", false, "message", "게시글을 찾을 수 없습니다."));
            }
            return ResponseEntity.ok(firebaseService.subscribeFeedNotification(postId, uid));
        } catch (Exception e) {
            log.error("[CommunityFeedInteractionsController] 알림 구독 오류: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "알림 설정 중 오류가 발생했습니다."));
        }
    }

    /** 알림 구독 해제 → notificationEnabled 반환 */
    @DeleteMapping("/{postId}/notification")
    public ResponseEntity<?> unsubscribe(@PathVariable String postId,
                                         HttpServletRequest httpRequest) {
        String uid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            if (uid == null || uid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false, "message", "로그인이 필요합니다."));
            }
            if (!firebaseService.feedExists(postId)) {
                return ResponseEntity.status(404).body(Map.of(
                        "success", false, "message", "게시글을 찾을 수 없습니다."));
            }
            return ResponseEntity.ok(firebaseService.unsubscribeFeedNotification(postId, uid));
        } catch (Exception e) {
            log.error("[CommunityFeedInteractionsController] 알림 해제 오류: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "알림 해제 중 오류가 발생했습니다."));
        }
    }
}
