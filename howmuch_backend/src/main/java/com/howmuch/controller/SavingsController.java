package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.SavingsHistoryResponse;
import com.howmuch.dto.SavingsStatsResponse;
import com.howmuch.service.SavingsService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 절약 정보 API 컨트롤러.
 * GET /api/savings/history: visits 데이터 기반 절약 내역 목록 반환
 * GET /api/savings/stats: 기간별 총 절약금액 + 주차/월별 차트 데이터 집계 반환
 */
@Slf4j
@RestController
@RequestMapping("/api/savings")
@RequiredArgsConstructor
public class SavingsController {

    private final SavingsService savingsService;

    /**
     * 절약 내역 목록 조회 (GET /api/savings/history)
     * 세션 토큰으로 인증된 유저의 visits 데이터를 기반으로 절약 내역 목록을 최신순으로 반환합니다.
     */
    @GetMapping("/history")
    public ResponseEntity<?> getSavingsHistory(HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false, "message", "인증 정보가 유효하지 않습니다."));
            }

            List<SavingsHistoryResponse> history = savingsService.getSavingsHistory(firebaseUid);
            return ResponseEntity.ok(history);
        } catch (Exception e) {
            log.error("[SavingsController] 절약 내역 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "절약 내역 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."));
        }
    }

    /**
     * 절약 통계 및 차트 데이터 조회 (GET /api/savings/stats?period=this_month|last_month|this_year)
     * 세션 토큰으로 인증된 유저의 visits 데이터를 기반으로 기간별 총 절약 금액 및 주차/월별 차트 집계 데이터를 반환합니다.
     */
    @GetMapping("/stats")
    public ResponseEntity<?> getSavingsStats(
            @RequestParam(value = "period", defaultValue = "this_month") String period,
            HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false, "message", "인증 정보가 유효하지 않습니다."));
            }

            SavingsStatsResponse stats = savingsService.getSavingsStats(firebaseUid, period);
            return ResponseEntity.ok(stats);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(java.util.Map.of(
                    "success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("[SavingsController] 절약 통계 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "절약 통계 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."));
        }
    }
}
