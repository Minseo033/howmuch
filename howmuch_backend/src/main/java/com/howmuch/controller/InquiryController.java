package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.InquiryRequest;
import com.howmuch.service.FirebaseService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 문의 API.
 * POST /api/inquiry        : 문의 등록 (세션 인증)
 * GET  /api/inquiry/my     : 내 문의 목록 (세션 인증, 최신순)
 */
@Slf4j
@RestController
@RequestMapping("/api/inquiry")
@RequiredArgsConstructor
public class InquiryController {

    private final FirebaseService firebaseService;

    /** 문의 등록 (POST /api/inquiry) */
    @PostMapping
    public ResponseEntity<?> createInquiry(@RequestBody InquiryRequest request,
                                           HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);

        if (firebaseUid == null || firebaseUid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false,
                    "message", "로그인이 필요합니다."
            ));
        }
        if (request == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "문의 내용을 입력해주세요."
            ));
        }

        if (request.getTitle() == null || request.getTitle().isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "제목은 필수입니다."
            ));
        }
        if (request.getTitle().trim().length() > 100) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "제목은 100자 이내로 입력해주세요."
            ));
        }
        if (request.getContent() == null || request.getContent().isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "내용은 필수입니다."
            ));
        }
        if (request.getContent().trim().length() > 2000) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "내용은 2000자 이내로 입력해주세요."
            ));
        }
        if (request.getCategory() != null && request.getCategory().trim().length() > 50) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "문의 유형은 50자 이내로 입력해주세요."
            ));
        }
        if (request.getImageUrls() != null && request.getImageUrls().size() > 3) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "사진은 최대 3장까지 첨부할 수 있습니다."
            ));
        }

        try {
            Map<String, Object> result = firebaseService.createInquiry(firebaseUid, request);
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("[InquiryController] 문의 등록 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "문의 등록 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 내 문의 목록 조회 (GET /api/inquiry/my) */
    @GetMapping("/my")
    public ResponseEntity<?> getMyInquiries(HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            List<Map<String, Object>> inquiries = firebaseService.getMyInquiries(firebaseUid);
            return ResponseEntity.ok(inquiries);
        } catch (Exception e) {
            log.error("[InquiryController] 내 문의 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "문의 목록 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }
}
