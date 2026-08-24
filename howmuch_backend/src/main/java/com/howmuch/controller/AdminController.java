package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import com.howmuch.service.PublicDataService;
import com.howmuch.service.ReportImageStorage;
import com.howmuch.service.SimpleRateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
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
 * DELETE /api/admin/reports/{id}                               : 제보와 첨부 사진 삭제
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
    private final ReportImageStorage reportImageStorage;
    private final PublicDataService publicDataService;
    private final SimpleRateLimiter rateLimiter;

    @Value("${admin.key:}")
    private String adminKey;

    @Value("${admin.auth.max-failures-per-5-min:10}")
    private int maxAdminAuthFailures = 10;

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
            String address = clientAddress(request);
            if (!rateLimiter.tryAcquire(
                    "admin-auth:" + address,
                    maxAdminAuthFailures,
                    5 * 60_000L)) {
                return ResponseEntity.status(429).body(Map.of(
                        "success", false,
                        "message", "어드민 로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요."));
            }
            log.warn("[AdminController] 잘못된 어드민 키 접근 차단");
            return ResponseEntity.status(401).body(Map.of(
                    "success", false,
                    "message", "어드민 키가 올바르지 않습니다."
            ));
        }
        return null;
    }

    private String clientAddress(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            String[] addresses = forwarded.split(",");
            for (int index = addresses.length - 1; index >= 0; index--) {
                String address = addresses[index].trim();
                if (!address.isBlank() && address.length() <= 64) {
                    return address;
                }
            }
        }
        String remoteAddress = request.getRemoteAddr();
        return remoteAddress != null && remoteAddress.length() <= 64
                ? remoteAddress
                : "unknown";
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
        ResponseEntity<?> invalidStatus = validateStatus(status);
        if (invalidStatus != null) return invalidStatus;

        try {
            String filter = "ALL".equalsIgnoreCase(status) ? null : status.toUpperCase();
            List<Map<String, Object>> reports = firebaseService.getAllReports(filter);
            return ResponseEntity.ok(reports);
        } catch (Exception e) {
            log.error("[AdminController] 제보 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "제보 목록 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 영수증 인증 목록 조회 (GET /api/admin/receipts?status=PENDING) */
    @GetMapping("/receipts")
    public ResponseEntity<?> getReceiptVerifications(
            @RequestParam(defaultValue = "PENDING") String status,
            HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;
        ResponseEntity<?> invalidStatus = validateStatus(status);
        if (invalidStatus != null) return invalidStatus;
        try {
            String filter = "ALL".equalsIgnoreCase(status) ? null : status.toUpperCase();
            return ResponseEntity.ok(firebaseService.getReceiptVerifications(filter));
        } catch (Exception e) {
            log.error("[AdminController] 영수증 인증 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "영수증 인증 목록을 불러오지 못했습니다."));
        }
    }

    /** 영수증 인증 승인 및 방문 기록 생성 */
    @PostMapping("/receipts/{id}/approve")
    public ResponseEntity<?> approveReceipt(
            @PathVariable String id, HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;
        ResponseEntity<?> invalidId = validateDocumentId(id);
        if (invalidId != null) return invalidId;
        try {
            return ResponseEntity.ok(firebaseService.approveReceiptVerification(id, "ADMIN"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(409).body(Map.of(
                    "success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("[AdminController] 영수증 인증 승인 중 오류 발생: id={}", id, e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "영수증 인증 승인에 실패했습니다."));
        }
    }

    /** 영수증 인증 반려 */
    @PostMapping("/receipts/{id}/reject")
    public ResponseEntity<?> rejectReceipt(
            @PathVariable String id,
            @RequestBody(required = false) Map<String, String> body,
            HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;
        ResponseEntity<?> invalidId = validateDocumentId(id);
        if (invalidId != null) return invalidId;
        String reason = body == null ? null : body.get("reason");
        if (reason == null || reason.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "반려 사유(reason)는 필수입니다."));
        }
        if (reason.trim().length() > 500) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "반려 사유는 500자 이내로 입력해주세요."));
        }
        try {
            firebaseService.rejectReceiptVerification(id, reason.trim(), "ADMIN");
            return ResponseEntity.ok(Map.of("success", true, "id", id, "status", "REJECTED"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(409).body(Map.of(
                    "success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("[AdminController] 영수증 인증 반려 중 오류 발생: id={}", id, e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "영수증 인증 반려에 실패했습니다."));
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
                    "message", "개요 지표 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** Cloudinary 사용량 (GET /api/admin/storage/report-images/usage) */
    @GetMapping("/storage/report-images/usage")
    public ResponseEntity<?> getReportImageStorageUsage(HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;

        try {
            return ResponseEntity.ok(reportImageStorage.getUsage());
        } catch (IllegalStateException e) {
            return ResponseEntity.status(503).body(Map.of(
                    "success", false,
                    "message", "Cloudinary 저장소가 설정되지 않았습니다."));
        } catch (Exception e) {
            log.error("[AdminController] Cloudinary 사용량 조회 중 오류 발생: ", e);
            return ResponseEntity.status(502).body(Map.of(
                    "success", false,
                    "message", "Cloudinary 사용량을 확인하지 못했습니다."));
        }
    }

    /** 공공데이터 캐시 스냅샷 (GET /api/admin/stores/snapshot, Firestore 읽기 0) */
    @GetMapping("/stores/snapshot")
    public ResponseEntity<?> getStoresSnapshot(HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;
        return ResponseEntity.ok(firebaseService.getGovStoresSnapshot());
    }

    /** 공공데이터 수동 동기화 (POST /api/admin/public-data/sync) */
    @PostMapping("/public-data/sync")
    public ResponseEntity<?> syncPublicData(HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;

        try {
            if (!publicDataService.syncAllPublicDataInBackground()) {
                return ResponseEntity.status(409).body(Map.of(
                        "success", false,
                        "message", "공공데이터 동기화가 이미 진행 중입니다."));
            }
            return ResponseEntity.accepted().body(Map.of(
                    "success", true,
                    "message", "공공데이터 동기화를 시작했습니다."));
        } catch (IllegalStateException e) {
            return ResponseEntity.status(503).body(Map.of(
                    "success", false,
                    "message", "공공데이터 API 키가 설정되지 않았습니다."));
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
                    "message", "회원 목록 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 회원 활동 상세 (GET /api/admin/users/{uid}/activity) — 제보/리뷰/방문/찜 개수 */
    @GetMapping("/users/{uid}/activity")
    public ResponseEntity<?> getUserActivity(@PathVariable String uid,
                                             HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;
        ResponseEntity<?> invalidId = validateDocumentId(uid);
        if (invalidId != null) return invalidId;

        try {
            return ResponseEntity.ok(firebaseService.getUserActivity(uid));
        } catch (Exception e) {
            log.error("[AdminController] 회원 활동 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "회원 활동 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 회원 삭제/강제 탈퇴 (DELETE /api/admin/users/{uid}) — users + 제보/리뷰/방문/찜 전부 삭제 */
    @org.springframework.web.bind.annotation.DeleteMapping("/users/{uid}")
    public ResponseEntity<?> deleteUser(@PathVariable String uid,
                                        HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;
        ResponseEntity<?> invalidId = validateDocumentId(uid);
        if (invalidId != null) return invalidId;

        try {
            Map<String, Object> result = firebaseService.deleteUser(uid);
            log.warn("[AdminController] 회원 강제 탈퇴 완료");
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("[AdminController] 회원 삭제 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "회원 삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 리뷰 목록 조회 (GET /api/admin/reviews) — 최신순 전체 */
    @GetMapping("/reviews")
    public ResponseEntity<?> getReviews(HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;

        try {
            return ResponseEntity.ok(firebaseService.getAllReviews());
        } catch (Exception e) {
            log.error("[AdminController] 리뷰 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "리뷰 목록 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 리뷰 삭제 (DELETE /api/admin/reviews/{id}) */
    @org.springframework.web.bind.annotation.DeleteMapping("/reviews/{id}")
    public ResponseEntity<?> deleteReview(@PathVariable String id,
                                          HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;
        ResponseEntity<?> invalidId = validateDocumentId(id);
        if (invalidId != null) return invalidId;

        try {
            firebaseService.deleteReview(id);
            log.warn("[AdminController] 리뷰 삭제 - id: {}", id);
            return ResponseEntity.ok(Map.of("success", true, "id", id));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("[AdminController] 리뷰 삭제 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "리뷰 삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 제보 승인 (POST /api/admin/reports/{id}/approve) */
    @PostMapping("/reports/{id}/approve")
    public ResponseEntity<?> approveReport(@PathVariable String id,
                                           HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;
        ResponseEntity<?> invalidId = validateDocumentId(id);
        if (invalidId != null) return invalidId;

        try {
            firebaseService.approveReport(id);
            log.info("[AdminController] 제보 승인 - id: {}", id);
            return ResponseEntity.ok(Map.of("success", true, "id", id, "status", "APPROVED"));
        } catch (IllegalStateException e) {
            return ResponseEntity.status(409).body(Map.of("success", false, "message", e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("[AdminController] 제보 승인 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "제보 승인 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
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
        ResponseEntity<?> invalidId = validateDocumentId(id);
        if (invalidId != null) return invalidId;

        String reason = body != null ? body.get("reason") : null;
        if (reason == null || reason.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "반려 사유(reason)는 필수입니다."
            ));
        }
        if (reason.trim().length() > 500) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "반려 사유는 500자 이내로 입력해주세요."));
        }

        try {
            firebaseService.rejectReport(id, reason.trim());
            log.info("[AdminController] 제보 반려 - id: {}", id);
            return ResponseEntity.ok(Map.of("success", true, "id", id, "status", "REJECTED"));
        } catch (IllegalStateException e) {
            return ResponseEntity.status(409).body(Map.of("success", false, "message", e.getMessage()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("[AdminController] 제보 반려 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "제보 반려 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 제보 삭제 (DELETE /api/admin/reports/{id}) - 첨부 사진까지 함께 삭제 */
    @DeleteMapping("/reports/{id}")
    public ResponseEntity<?> deleteReport(@PathVariable String id,
                                          HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;
        ResponseEntity<?> invalidId = validateDocumentId(id);
        if (invalidId != null) return invalidId;

        try {
            Map<String, Object> result = firebaseService.deleteReportAsAdmin(id);
            log.warn("[AdminController] 제보 삭제 - id: {}, 삭제 사진: {}",
                    id, result.get("deletedImages"));
            return ResponseEntity.ok(result);
        } catch (java.util.NoSuchElementException | IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of(
                    "success", false, "message", e.getMessage()));
        } catch (IllegalStateException e) {
            log.warn("[AdminController] 제보 사진 저장소가 설정되지 않아 삭제를 중단했습니다. id={}", id);
            return ResponseEntity.status(503).body(Map.of(
                    "success", false,
                    "message", "사진 저장소를 준비 중입니다. 잠시 후 다시 시도해주세요."));
        } catch (Exception e) {
            log.error("[AdminController] 제보 삭제 중 오류 발생: id={}", id, e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "제보 삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."));
        }
    }

    /** 문의 목록 조회 (GET /api/admin/inquiries) — 최신순 전체 */
    @GetMapping("/inquiries")
    public ResponseEntity<?> getInquiries(HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;

        try {
            return ResponseEntity.ok(firebaseService.getAllInquiries());
        } catch (Exception e) {
            log.error("[AdminController] 문의 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "문의 목록 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 문의 답변 등록 (POST /api/admin/inquiries/{id}/answer, body: {"answer": "..."}) */
    @PostMapping("/inquiries/{id}/answer")
    public ResponseEntity<?> answerInquiry(@PathVariable String id,
                                           @RequestBody(required = false) Map<String, String> body,
                                           HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;
        ResponseEntity<?> invalidId = validateDocumentId(id);
        if (invalidId != null) return invalidId;

        String answer = body != null ? body.get("answer") : null;
        if (answer == null || answer.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "답변 내용(answer)은 필수입니다."
            ));
        }
        if (answer.trim().length() > 2000) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "답변은 2000자 이내로 입력해주세요."
            ));
        }

        try {
            Map<String, Object> result = firebaseService.answerInquiry(id, answer.trim());
            log.info("[AdminController] 문의 답변 등록 - id: {}", id);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of(
                    "success", false,
                    "message", e.getMessage()
            ));
        } catch (Exception e) {
            log.error("[AdminController] 문의 답변 등록 중 오류 발생: id={}", id, e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "문의 답변 등록 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 댓글/답글 목록 조회 (GET /api/admin/comments) — 최신순 전체, 모더레이션용 */
    @GetMapping("/comments")
    public ResponseEntity<?> getComments(HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;

        try {
            return ResponseEntity.ok(firebaseService.getAllComments());
        } catch (Exception e) {
            log.error("[AdminController] 댓글 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "댓글 목록 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 댓글/답글 삭제 (DELETE /api/admin/comments/{id}) */
    @org.springframework.web.bind.annotation.DeleteMapping("/comments/{id}")
    public ResponseEntity<?> deleteComment(@PathVariable String id,
                                           HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;
        ResponseEntity<?> invalidId = validateDocumentId(id);
        if (invalidId != null) return invalidId;

        try {
            firebaseService.deleteComment(id);
            log.warn("[AdminController] 댓글 삭제 - id: {}", id);
            return ResponseEntity.ok(Map.of("success", true, "id", id));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("[AdminController] 댓글 삭제 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "댓글 삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 알림 발송 (POST /api/admin/notifications, body: {audience: ALL|USER, title, body, type?, targetUid?}). */
    @PostMapping("/notifications")
    public ResponseEntity<?> sendNotification(@RequestBody Map<String, String> body,
                                              HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;

        String title = body != null ? body.get("title") : null;
        String content = body != null ? body.get("body") : null;
        String type = body != null ? body.get("type") : null;
        String targetUid = body != null ? body.get("targetUid") : null;
        String audience = body != null ? body.get("audience") : null;

        if (title == null || title.isBlank() || content == null || content.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "제목(title)과 내용(body)은 필수입니다."
            ));
        }
        if (title.length() > 100 || content.length() > 500) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "제목은 100자, 내용은 500자 이내로 입력해주세요."
            ));
        }
        if (type != null && type.trim().length() > 50) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "알림 유형은 50자 이내로 입력해주세요."));
        }
        if (audience == null || !("ALL".equalsIgnoreCase(audience.trim())
                || "USER".equalsIgnoreCase(audience.trim()))) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "발송 대상(audience)은 ALL 또는 USER로 지정해주세요."));
        }
        boolean userAudience = "USER".equalsIgnoreCase(audience.trim());
        boolean hasTarget = targetUid != null && !targetUid.isBlank();
        if (userAudience && !hasTarget) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "특정 회원 발송에는 대상 사용자 ID가 필요합니다."));
        }
        if (!userAudience && hasTarget) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "전체 발송에는 대상 사용자 ID를 함께 보낼 수 없습니다."));
        }
        if (hasTarget && !isValidDocumentId(targetUid.trim())) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "대상 사용자 ID 형식이 올바르지 않습니다."));
        }

        try {
            Map<String, Object> result = firebaseService.sendAdminNotification(
                    userAudience ? targetUid.trim() : null,
                    title.trim(), content.trim(), type == null ? null : type.trim());
            log.warn("[AdminController] 알림 발송 완료 - 발송 수: {}", result.get("sent"));
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of(
                    "success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("[AdminController] 알림 발송 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "알림 발송 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 커뮤니티 활동 지표 (GET /api/admin/community/stats) — 댓글/좋아요/알림 수 */
    @GetMapping("/community/stats")
    public ResponseEntity<?> getCommunityStats(HttpServletRequest httpRequest) {
        ResponseEntity<?> denied = guard(httpRequest);
        if (denied != null) return denied;

        try {
            return ResponseEntity.ok(firebaseService.getCommunityStats());
        } catch (Exception e) {
            log.error("[AdminController] 커뮤니티 지표 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "커뮤니티 지표 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    private ResponseEntity<?> validateStatus(String status) {
        if (status != null && List.of("PENDING", "APPROVED", "REJECTED", "ALL")
                .stream().noneMatch(value -> value.equalsIgnoreCase(status.trim()))) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "상태 필터 형식이 올바르지 않습니다."));
        }
        return null;
    }

    private ResponseEntity<?> validateDocumentId(String id) {
        if (!isValidDocumentId(id)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "대상 ID 형식이 올바르지 않습니다."));
        }
        return null;
    }

    private boolean isValidDocumentId(String id) {
        return id != null && !id.isBlank() && id.length() <= 512 && !id.contains("/");
    }
}
