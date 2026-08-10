package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.NotificationResponseDto;
import com.howmuch.service.FirebaseService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 알림 API 컨트롤러.
 * GET /api/notifications: 인증된 사용자의 알림 목록 반환
 * PATCH /api/notifications/{id}/read: 알림 읽음 처리
 */
@Slf4j
@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final FirebaseService firebaseService;

    /**
     * 내 알림 목록 조회
     */
    @GetMapping
    public ResponseEntity<?> getUserNotifications(HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        log.info("[NotificationController] 내 알림 목록 조회 요청 - uid: {}", firebaseUid);

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body("인증 정보가 유효하지 않습니다.");
            }

            List<NotificationResponseDto> notifications = firebaseService.getNotifications(firebaseUid);
            return ResponseEntity.ok(notifications);
        } catch (Exception e) {
            log.error("[NotificationController] 알림 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body("알림 목록 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 알림 읽음 처리
     */
    @PatchMapping("/{id}/read")
    public ResponseEntity<?> markAsRead(@PathVariable String id, HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        log.info("[NotificationController] 알림 읽음 처리 요청 - uid: {}, notificationId: {}", firebaseUid, id);

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body("인증 정보가 유효하지 않습니다.");
            }

            firebaseService.markNotificationAsRead(id);
            return ResponseEntity.ok("알림 읽음 처리 완료");
        } catch (Exception e) {
            log.error("[NotificationController] 알림 읽음 처리 중 오류 발생: ", e);
            return ResponseEntity.status(500).body("알림 읽음 처리 중 오류가 발생했습니다: " + e.getMessage());
        }
    }
}
