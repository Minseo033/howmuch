package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.SavingsGoalRequest;
import com.howmuch.dto.SavingsGoalResponse;
import com.howmuch.service.FirebaseService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 절약 목표 API 컨트롤러.
 * GET /api/savings/goal: 내 절약 목표 조회 (미설정 시 goalAmount=null)
 * POST /api/savings/goal: 절약 목표 설정 — users/{uid} 문서에 병합 저장되어 앱 재시작 후에도 유지
 *
 * 참고: /api/savings/history·/api/savings/stats 는 SavingsController(지환)가 담당합니다.
 */
@Slf4j
@RestController
@RequestMapping("/api/savings/goal")
@RequiredArgsConstructor
public class SavingsGoalController {

    private final FirebaseService firebaseService;

    /** 내 절약 목표 조회 (GET /api/savings/goal) */
    @GetMapping
    public ResponseEntity<?> getSavingsGoal(HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        log.info("[SavingsGoalController] 절약 목표 조회 요청 - uid: {}", firebaseUid);

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body("인증 정보가 유효하지 않습니다.");
            }
            SavingsGoalResponse goal = firebaseService.getSavingsGoal(firebaseUid);
            return ResponseEntity.ok(goal);
        } catch (Exception e) {
            log.error("[SavingsGoalController] 절약 목표 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "절약 목표 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 절약 목표 설정 (POST /api/savings/goal) */
    @PostMapping
    public ResponseEntity<?> saveSavingsGoal(@RequestBody SavingsGoalRequest request,
                                             HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        log.info("[SavingsGoalController] 절약 목표 설정 요청 - uid: {}, goalAmount: {}", firebaseUid, request.getGoalAmount());

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body("인증 정보가 유효하지 않습니다.");
            }
            if (request.getGoalAmount() == null || request.getGoalAmount() < 0) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "goalAmount는 0 이상의 필수 값입니다."
                ));
            }
            SavingsGoalResponse saved = firebaseService.saveSavingsGoal(firebaseUid, request.getGoalAmount());
            return ResponseEntity.ok(saved);
        } catch (Exception e) {
            log.error("[SavingsGoalController] 절약 목표 설정 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "절약 목표 설정 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }
}