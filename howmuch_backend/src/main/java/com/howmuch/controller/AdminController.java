package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.List;
import java.util.Map;

/**
 * 어드민 제보 처리 API (웹 어드민 페이지 web/admin.html 전용).
 * GET  /api/admin/reports?status=PENDING|APPROVED|REJECTED|ALL : 제보 목록 (기본 PENDING)
 * POST /api/admin/reports/{id}/approve                         : 제보 승인
 * POST /api/admin/reports/{id}/reject                          : 제보 반려 (body: {"reason": "..."} 필수)
 *
 * 인증: X-Admin-Key 헤더를 admin.key(환경변수 ADMIN_KEY)와 대조.
 * 앱 세션(카카오 로그인)과 무관한 어드민 전용 비밀번호. 미설정 시 모든 어드민 API는 403.
 */
@Slf4j
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

    private final FirebaseService firebaseService;

    @Value("${admin.key:}")
    private String adminKey;

    /** 어드민 접근 제어 공통 처리. 통과 시 null, 아니면 그대로 반환할 에러 응답 */
    private ResponseEntity<?> guard(HttpServletRequest request) {
        if (adminKey == null || adminKey.isBlank()) {
            return ResponseEntity.status(403).body(Map.of(
                    "success", false,
                    "message", "서버에 ADMIN_KEY가 설정되지 않았습니다."
            ));
        }
        String provided = request.getHeader("X-Admin-Key");
        if (provided == null || !constantTimeEquals(provided, adminKey)) {
            // 💡 브루트포스 완화: 실패 시 1초 지연 (무차별 대입 속도 제한)
            try {
                Thread.sleep(1000);
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
            }
            log.warn("[AdminController] 잘못된 어드민 키 접근 차단");
            return ResponseEntity.status(401).body(Map.of(
                    "success", false,
                    "message", "어드민 키가 올바르지 않습니다."
            ));
        }
        return null;
    }

    /** 타이밍 공격 방지용 상수 시간 비교 */
    private boolean constantTimeEquals(String a, String b) {
        return MessageDigest.isEqual(
                a.getBytes(StandardCharsets.UTF_8),
                b.getBytes(StandardCharsets.UTF_8));
    }

    /** 제보 목록 조회 (GET /api/admin/reports?status=PENDING) */
    @GetMapping("/reports")
    public ResponseEntity<?> getReports(@RequestParam(defaultValue = "PENDING") String status,
                                        HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;

        try {
            String filter = "ALL".equalsIgnoreCase(status) ? null : status.toUpperCase();
            List<Map<String, Object>> reports = firebaseService.getAllReports(filter);
            return ResponseEntity.ok(reports);
        } catch (Exception e) {
            log.error("[AdminController] 제보 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "제보 목록 조회 중 오류가 발생했습니다: " + e.getMessage()
            ));
        }
    }

    /** 대시보드 개요 지표 (GET /api/admin/overview) */
    @GetMapping("/overview")
    public ResponseEntity<?> getOverview(HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;

        try {
            return ResponseEntity.ok(firebaseService.getAdminOverview());
        } catch (Exception e) {
            log.error("[AdminController] 개요 지표 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "개요 지표 조회 중 오류가 발생했습니다: " + e.getMessage()
            ));
        }
    }

    /** 회원 목록 조회 (GET /api/admin/users) */
    @GetMapping("/users")
    public ResponseEntity<?> getUsers(HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;

        try {
            return ResponseEntity.ok(firebaseService.getAllUsers());
        } catch (Exception e) {
            log.error("[AdminController] 회원 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "회원 목록 조회 중 오류가 발생했습니다: " + e.getMessage()
            ));
        }
    }

    /** 제보 승인 (POST /api/admin/reports/{id}/approve) */
    @PostMapping("/reports/{id}/approve")
    public ResponseEntity<?> approveReport(@PathVariable String id,
                                           HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;

        try {
            firebaseService.approveReport(id);
            log.info("[AdminController] 제보 승인 - id: {}", id);
            return ResponseEntity.ok(Map.of("success", true, "id", id, "status", "APPROVED"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("[AdminController] 제보 승인 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "제보 승인 중 오류가 발생했습니다: " + e.getMessage()
            ));
        }
    }

    /** 제보 반려 (POST /api/admin/reports/{id}/reject, body: {"reason": "..."}) */
    @PostMapping("/reports/{id}/reject")
    public ResponseEntity<?> rejectReport(@PathVariable String id,
                                          @RequestBody(required = false) Map<String, String> body,
                                          HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;

        String reason = body != null ? body.get("reason") : null;
        if (reason == null || reason.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "반려 사유(reason)는 필수입니다."
            ));
        }

        try {
            firebaseService.rejectReport(id, reason.trim());
            log.info("[AdminController] 제보 반려 - id: {}, reason: {}", id, reason.trim());
            return ResponseEntity.ok(Map.of("success", true, "id", id, "status", "REJECTED"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("[AdminController] 제보 반려 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "제보 반려 중 오류가 발생했습니다: " + e.getMessage()
            ));
        }
    }
}
