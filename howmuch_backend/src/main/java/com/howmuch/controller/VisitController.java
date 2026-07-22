package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.VisitResponseDto;
import com.howmuch.service.FirebaseService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 방문 기록 API 컨트롤러.
 * GET /api/visits: 인증된 사용자의 방문 기록 목록 (방문 일시, 매장명, 절약 금액 등) 반환
 */
@Slf4j
@RestController
@RequestMapping("/api/visits")
@RequiredArgsConstructor
public class VisitController {

    private final FirebaseService firebaseService;

    /**
     * GET /api/visits
     * 세션 토큰 인증 필요 (SessionAuthFilter에서 UID_ATTRIBUTE 주입)
     */
    @GetMapping
    public ResponseEntity<?> getMyVisits(HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        log.info("[VisitController] 방문 기록 목록 조회 요청 - uid: {}", firebaseUid);

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false,
                        "message", "인증 정보가 유효하지 않습니다. 다시 로그인해주세요."
                ));
            }

            List<VisitResponseDto> visits = firebaseService.getUserVisits(firebaseUid);
            return ResponseEntity.ok(visits);
        } catch (Exception e) {
            log.error("[VisitController] 방문 기록 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "방문 기록 조회 중 오류가 발생했습니다: " + e.getMessage()
            ));
        }
    }
}
