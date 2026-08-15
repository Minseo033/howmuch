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

    /** 로그인한 사용자가 작성한 리뷰 목록 조회 (최신순) */
    @GetMapping("/me")
    public ResponseEntity<?> getMyReviews(HttpServletRequest httpRequest) {
        String authorUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            List<Map<String, Object>> reviews = firebaseService.getMyReviews(authorUid);
            return ResponseEntity.ok(reviews);
        } catch (Exception e) {
            log.error("[ReviewController] 내 리뷰 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "내 리뷰 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

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
                    "message", "리뷰 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
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
            if (authorUid == null || authorUid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false,
                        "message", "인증이 필요합니다. 다시 로그인해주세요."
                ));
            }
            if (request == null) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "리뷰 입력값이 필요합니다."
                ));
            }

            normalizeReviewRequest(request);
            if (isBlank(request.getStoreId())
                    || isBlank(request.getStoreName())
                    || isBlank(request.getMenu())
                    || isBlank(request.getContent())
                    || request.getStars() < 1 || request.getStars() > 5) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "매장 정보, 방문 메뉴, 리뷰 내용, 별점(1~5)은 필수입니다."
                ));
            }
            if (request.getPrice() == null || request.getPrice() <= 0 || request.getPrice() > 10_000_000) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "실제 결제 가격은 1원 이상 1,000만원 이하로 입력해주세요."
                ));
            }
            // 💡 입력 길이 제한 (Firestore 쓰기 폭증/악용 방지)
            if (request.getContent().length() > 2000) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "리뷰 내용은 2000자 이내로 입력해주세요."
                ));
            }
            if (request.getStoreId().length() > 200
                    || request.getStoreName().length() > 100
                    || request.getAuthorName().length() > 50
                    || request.getMenu().length() > 100) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "입력값이 허용 길이를 초과했습니다."
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
                    "message", "리뷰 저장 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    private void normalizeReviewRequest(ReviewRequest request) {
        request.setStoreId(trimToNull(request.getStoreId()));
        request.setStoreName(trimToNull(request.getStoreName()));
        request.setMenu(trimToNull(request.getMenu()));
        request.setContent(trimToNull(request.getContent()));

        String authorName = trimToNull(request.getAuthorName());
        request.setAuthorName(authorName == null ? "사용자" : authorName);
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private String trimToNull(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
