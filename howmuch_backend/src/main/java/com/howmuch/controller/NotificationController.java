package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.NotificationResponseDto;
import com.howmuch.dto.NotificationSettingsDto;
import com.howmuch.service.FirebaseService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 알림 API 컨트롤러.
 * GET  /api/notifications           내 알림 목록 (최신순)
 * POST /api/notifications/{id}/read 알림 읽음 처리 (본인 알림만)
 * GET  /api/notifications/settings  내 알림 설정 조회
 * PUT  /api/notifications/settings  내 알림 설정 저장
 */
@Slf4j
@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final FirebaseService firebaseService;

    /** 내 알림 목록 조회 */
    @GetMapping
    public ResponseEntity<?> getUserNotifications(HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        log.info("[NotificationController] 내 알림 목록 조회 요청 - uid: {}", firebaseUid);

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false, "message", "인증 정보가 유효하지 않습니다."));
            }
            List<NotificationResponseDto> notifications = firebaseService.getNotifications(firebaseUid);
            return ResponseEntity.ok(notifications);
        } catch (Exception e) {
            log.error("[NotificationController] 알림 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "알림 목록 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."));
        }
    }

    @GetMapping("/settings")
    public ResponseEntity<?> getNotificationSettings(HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        if (firebaseUid == null || firebaseUid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false, "message", "인증 정보가 유효하지 않습니다."));
        }

        try {
            return ResponseEntity.ok(firebaseService.getNotificationSettings(firebaseUid));
        } catch (Exception e) {
            log.error("[NotificationController] 알림 설정 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "알림 설정 조회 중 오류가 발생했습니다."));
        }
    }

    @PutMapping("/settings")
    public ResponseEntity<?> saveNotificationSettings(
            @Valid @RequestBody NotificationSettingsDto settings,
            HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        if (firebaseUid == null || firebaseUid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false, "message", "인증 정보가 유효하지 않습니다."));
        }

        try {
            return ResponseEntity.ok(firebaseService.saveNotificationSettings(firebaseUid, settings));
        } catch (Exception e) {
            log.error("[NotificationController] 알림 설정 저장 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "알림 설정 저장 중 오류가 발생했습니다."));
        }
    }

    /** 알림 읽음 처리 (본인 알림만 가능) */
    @PostMapping("/{id}/read")
    public ResponseEntity<?> markAsRead(@PathVariable String id,
                                        HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        log.info("[NotificationController] 알림 읽음 처리 요청 - uid: {}, notificationId: {}", firebaseUid, id);

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false, "message", "인증 정보가 유효하지 않습니다."));
            }
            firebaseService.markNotificationAsRead(id, firebaseUid);
            return ResponseEntity.ok(Map.of("success", true, "id", id));
        } catch (IllegalArgumentException e) {
            // 존재하지 않거나 권한 없는 알림
            return ResponseEntity.status(404).body(Map.of(
                    "success", false, "message", "알림을 찾을 수 없습니다."));
        } catch (Exception e) {
            log.error("[NotificationController] 알림 읽음 처리 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "알림 읽음 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."));
        }
    }
}
