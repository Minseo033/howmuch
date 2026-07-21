package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.ReviewRequest;
import com.howmuch.service.FirebaseService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 매장 리뷰 API.
 * 조회(GET)는 공개, 작성(POST)은 세션 토큰 인증 필요 (SessionAuthFilter가 uid 주입).
 */
@Slf4j
@RestController
@RequestMapping("/api/review")
@RequiredArgsConstructor
public class ReviewController {

    private final FirebaseService firebaseService;

    /** 특정 매장의 리뷰 목록 조회 (최신순) */
    @GetMapping
    public ResponseEntity<?> getReviews(@RequestParam String storeId) {
        try {
            List<Map<String, Object>> reviews = firebaseService.getReviews(storeId);
            return ResponseEntity.ok(reviews);
        } catch (Exception e) {
            log.error("[ReviewController] 리뷰 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "리뷰 조회 중 오류가 발생했습니다: " + e.getMessage()
            ));
        }
    }

    /** 리뷰 작성 (인증 필요, 작성자 uid는 세션에서 주입) */
    @PostMapping
    public ResponseEntity<?> createReview(
            HttpServletRequest httpRequest,
            @RequestBody ReviewRequest request) {
        String authorUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            if (request.getStoreId() == null || request.getStoreId().isBlank()
                    || request.getContent() == null || request.getContent().isBlank()
                    || request.getStars() < 1 || request.getStars() > 5) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "매장 정보, 리뷰 내용, 별점(1~5)은 필수입니다."
                ));
            }

            String reviewId = firebaseService.saveReview(authorUid, request);
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "reviewId", reviewId,
                    "message", "리뷰가 등록되었습니다."
            ));
        } catch (Exception e) {
            log.error("[ReviewController] 리뷰 저장 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "리뷰 저장 중 오류가 발생했습니다: " + e.getMessage()
            ));
        }
    }
}