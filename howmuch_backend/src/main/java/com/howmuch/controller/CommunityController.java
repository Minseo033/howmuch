package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.FeedDetailResponseDto;
import com.howmuch.dto.FeedResponseDto;
import com.howmuch.service.FirebaseService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/community")
@RequiredArgsConstructor
public class CommunityController {

    private final FirebaseService firebaseService;

    // 💡 커뮤니티 피드 목록 조회 (제보 현황)
    @GetMapping("/feed")
    public ResponseEntity<?> getCommunityFeeds() {
        try {
            List<FeedResponseDto> feeds = firebaseService.getCommunityFeeds();
            return ResponseEntity.ok(feeds);
        } catch (Exception e) {
            log.error("Failed to fetch community feeds", e);
            return ResponseEntity.internalServerError().body(Map.of(
                    "success", false, "message", "커뮤니티 글을 불러오지 못했습니다."));
        }
    }

    // 💡 커뮤니티 피드 상세 조회
    @GetMapping("/feed/{id}")
    public ResponseEntity<?> getFeedDetail(@PathVariable String id,
                                           HttpServletRequest request) {
        if (!isValidDocumentId(id)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "게시글 ID가 올바르지 않습니다."));
        }
        try {
            String uid = (String) request.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
            FeedDetailResponseDto detail = firebaseService.getCommunityFeedDetail(id, uid);
            if (detail == null) {
                return ResponseEntity.status(404).body(Map.of(
                        "success", false, "message", "게시글을 찾을 수 없습니다."));
            }
            return ResponseEntity.ok(detail);
        } catch (Exception e) {
            log.error("Failed to fetch feed detail", e);
            return ResponseEntity.internalServerError().body(Map.of(
                    "success", false, "message", "게시글을 불러오지 못했습니다."));
        }
    }

    private boolean isValidDocumentId(String value) {
        return value != null && !value.isBlank()
                && value.length() <= 512 && !value.contains("/");
    }
}
