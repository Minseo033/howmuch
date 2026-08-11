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

@Slf4j
@RestController
@RequestMapping("/api/community")
@RequiredArgsConstructor
public class CommunityController {

    private final FirebaseService firebaseService;

    // 💡 커뮤니티 피드 목록 조회 (제보 현황)
    @GetMapping("/feed")
    public ResponseEntity<List<FeedResponseDto>> getCommunityFeeds() {
        try {
            List<FeedResponseDto> feeds = firebaseService.getCommunityFeeds();
            return ResponseEntity.ok(feeds);
        } catch (Exception e) {
            log.error("Failed to fetch community feeds", e);
            return ResponseEntity.internalServerError().build();
        }
    }

    // 💡 커뮤니티 피드 상세 조회
    @GetMapping("/feed/{id}")
    public ResponseEntity<FeedDetailResponseDto> getFeedDetail(@PathVariable String id,
                                                               HttpServletRequest request) {
        try {
            String uid = (String) request.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
            FeedDetailResponseDto detail = firebaseService.getCommunityFeedDetail(id, uid);
            if (detail == null) {
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.ok(detail);
        } catch (Exception e) {
            log.error("Failed to fetch feed detail for id: " + id, e);
            return ResponseEntity.internalServerError().build();
        }
    }
}
