package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.VisitRequest;
import com.howmuch.dto.VisitResponseDto;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.ReferencePrices;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 방문 기록 API 컨트롤러.
 * GET  /api/visits: 인증된 사용자의 방문 기록 목록 (방문 일시, 매장명, 절약 금액 등) 반환
 * POST /api/visits: 방문 인증 생성 — 절약 금액(savedAmount)은 서버에서 계산해 저장
 */
@Slf4j
@RestController
@RequestMapping("/api/visits")
@RequiredArgsConstructor
public class VisitController {

    private static final String LOCATION_VERIFICATION = "LOCATION";
    private static final double MAX_LOCATION_VERIFICATION_DISTANCE_METERS = 300.0;

    private final FirebaseService firebaseService;

    /**
     * 방문 기록 목록 조회 (GET /api/visits)
     * 세션 토큰으로 인증된 유저의 Firestore 방문 기록(방문 일시, 매장명, 절약 금액 등)을 최신순으로 조회합니다.
     */
    @GetMapping
    public ResponseEntity<?> getUserVisits(HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        log.info("[VisitController] 방문 기록 목록 조회 요청 - uid: {}", firebaseUid);

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body("인증 정보가 유효하지 않습니다.");
            }

            List<VisitResponseDto> visits = firebaseService.getUserVisits(firebaseUid);
            return ResponseEntity.ok(visits);
        } catch (Exception e) {
            log.error("[VisitController] 방문 기록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body("방문 기록 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.");
        }
    }

    /**
     * 예상 절약 금액 미리보기 (GET /api/visits/estimate?storeName=&menu=&price=)
     * 인증 화면의 "예상 절약 금액" 카드에서 사용. POST와 동일한 룰로 계산해 기준가도 함께 반환.
     */
    @GetMapping("/estimate")
    public ResponseEntity<?> estimateSavedAmount(
            @RequestParam String storeName,
            @RequestParam(required = false) String menu,
            @RequestParam(defaultValue = "0") long price,
            HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        if (firebaseUid == null || firebaseUid.isBlank()) {
            return ResponseEntity.status(401).body("인증 정보가 유효하지 않습니다.");
        }

        String industry = firebaseService.findIndustryByStoreName(storeName);
        long referencePrice = ReferencePrices.referencePrice(menu, industry);
        long savedAmount = Math.max(0L, referencePrice - price);
        return ResponseEntity.ok(Map.of(
                "referencePrice", referencePrice,
                "savedAmount", savedAmount,
                "matchedByMenu", ReferencePrices.matchMenuPrice(menu) != null
        ));
    }

    /**
     * 방문 인증 생성 (POST /api/visits)
     * 절약 금액은 클라이언트 입력이 아닌 서버 룰(참가격 − 결제가)로 계산해 저장합니다.
     */
    @PostMapping
    public ResponseEntity<?> createVisit(@RequestBody VisitRequest request,
                                         HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        log.info("[VisitController] 방문 인증 생성 요청 - uid: {}, store: {}", firebaseUid, request.getStoreName());

        if (firebaseUid == null || firebaseUid.isBlank()) {
            return ResponseEntity.status(401).body("인증 정보가 유효하지 않습니다.");
        }
        if (request.getStoreName() == null || request.getStoreName().isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "storeName은 필수입니다."
            ));
        }
        if (request.getPrice() == null || request.getPrice() < 0) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "price는 0 이상의 숫자여야 합니다."
            ));
        }
        if (!LOCATION_VERIFICATION.equalsIgnoreCase(request.getVerificationMethod())) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "현재 위치 인증이 필요합니다."
            ));
        }
        Double distanceMeters = request.getVerificationDistanceMeters();
        if (distanceMeters == null
                || !Double.isFinite(distanceMeters)
                || distanceMeters < 0
                || distanceMeters > MAX_LOCATION_VERIFICATION_DISTANCE_METERS) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "매장 300m 이내에서 인증해주세요."
            ));
        }
        // 💡 입력 상한 검증 (비정상 대형 값/문자열 악용 방지)
        if (request.getStoreName().length() > 100
                || (request.getMenu() != null && request.getMenu().length() > 100)
                || request.getPrice() > 10_000_000L) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "입력값이 허용 범위를 초과했습니다."
            ));
        }

        try {
            String industry = request.getIndustry();
            if (industry == null || industry.isBlank()) {
                industry = firebaseService.findIndustryByStoreName(request.getStoreName());
            }
            // 💡 절약 금액 = 참가격(시장 평균가) − 결제가 (ReferencePrices, 메뉴 매칭 우선)
            long savedAmount = ReferencePrices.savedAmount(
                    request.getMenu(), industry, request.getPrice());
            String visitId = firebaseService.saveVisit(firebaseUid, request, savedAmount);
            log.info("[VisitController] 방문 인증 완료 - id: {}, savedAmount: {}", visitId, savedAmount);
            return ResponseEntity.ok(Map.of(
                "success", true,
                "id", visitId,
                "savedAmount", savedAmount,
                "verificationMethod", LOCATION_VERIFICATION,
                "verificationDistanceMeters", distanceMeters
            ));
        } catch (Exception e) {
            log.error("[VisitController] 방문 인증 저장 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "방문 인증 저장 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }
}
