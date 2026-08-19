package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.VisitRequest;
import com.howmuch.dto.VisitResponseDto;
import com.howmuch.dto.StoreCoordinates;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.ReferencePrices;
import com.howmuch.service.ReceiptOcrService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 방문 기록 API 컨트롤러.
 * GET  /api/visits: 인증된 사용자의 방문 기록 목록 (방문 일시, 매장명, 절약 금액 등) 반환
 * POST /api/visits: 방문 인증 생성 — 절약 금액(savedAmount)은 서버에서 계산해 저장
 */
@Slf4j
@RestController
@RequestMapping("/api/visits")
public class VisitController {

    private static final String LOCATION_VERIFICATION = "LOCATION";
    private static final double MAX_LOCATION_VERIFICATION_DISTANCE_METERS = 50.0;

    private final FirebaseService firebaseService;
    private final ReceiptOcrService receiptOcrService;

    @Autowired
    public VisitController(FirebaseService firebaseService, ReceiptOcrService receiptOcrService) {
        this.firebaseService = firebaseService;
        this.receiptOcrService = receiptOcrService;
    }

    /** 기존 단위 테스트와 수동 생성 코드의 호환성을 유지합니다. */
    public VisitController(FirebaseService firebaseService) {
        this(firebaseService, new ReceiptOcrService());
    }

    @PostMapping(value = "/receipt", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> submitReceiptVerification(
            HttpServletRequest httpRequest,
            @RequestParam String storeId,
            @RequestParam String storeName,
            @RequestParam(required = false, defaultValue = "") String menu,
            @RequestParam long price,
            @RequestParam("images") List<MultipartFile> images) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        if (firebaseUid == null || firebaseUid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of("success", false, "message", "로그인이 필요합니다."));
        }
        List<String> uploaded = List.of();
        try {
            if (storeId == null || storeId.isBlank() || storeName == null || storeName.isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "매장 정보가 필요합니다."));
            }
            if (price < 0 || price > 10_000_000L) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "결제 금액을 확인해주세요."));
            }
            if (images == null || images.size() != 1) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "영수증 사진 1장을 첨부해주세요."));
            }
            ReceiptOcrService.Result ocrResult = receiptOcrService.analyze(
                    images.get(0).getBytes(), storeName, price);
            uploaded = firebaseService.uploadReportImages(firebaseUid, images);
            String id = firebaseService.saveReceiptVerification(
                    firebaseUid, storeId, storeName, menu, price, uploaded, ocrResult);
            String status = "PENDING";
            String visitId = null;
            if (ocrResult.shouldAutoApprove()) {
                try {
                    Map<String, Object> approval = firebaseService.approveReceiptVerification(id, "AUTO_OCR");
                    status = String.valueOf(approval.get("status"));
                    visitId = String.valueOf(approval.get("visitId"));
                } catch (Exception autoApprovalError) {
                    log.warn("OCR 자동 승인 실패, 관리자 검토로 전환합니다. receiptId={}", id, autoApprovalError);
                }
            }
            Map<String, Object> response = new java.util.HashMap<>();
            response.put("success", true);
            response.put("id", id);
            response.put("status", status);
            response.put("ocrStatus", ocrResult.status());
            response.put("ocrScore", ocrResult.score());
            if (visitId != null) response.put("visitId", visitId);
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", e.getMessage()));
        } catch (Exception e) {
            if (!uploaded.isEmpty()) {
                try { firebaseService.deleteReportImages(firebaseUid, uploaded); } catch (Exception ignored) {}
            }
            log.error("영수증 인증 요청 저장 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of("success", false, "message", "영수증 인증 요청을 저장하지 못했습니다."));
        }
    }

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
        if (!isValidLatitude(request.getLatitude()) || !isValidLongitude(request.getLongitude())) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "현재 위치 좌표를 확인할 수 없습니다. 다시 시도해주세요."
            ));
        }
        if (request.getLocationAccuracyMeters() == null
                || !Double.isFinite(request.getLocationAccuracyMeters())
                || request.getLocationAccuracyMeters() < 0
                || request.getLocationAccuracyMeters() > MAX_LOCATION_VERIFICATION_DISTANCE_METERS) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "현재 위치 정확도가 낮아요. 잠시 후 다시 시도해주세요."
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
            Optional<StoreCoordinates> storeCoordinates = firebaseService.findStoreCoordinates(
                    request.getStoreId(), request.getStoreName());
            if (storeCoordinates.isEmpty()) {
                return ResponseEntity.status(422).body(Map.of(
                        "success", false,
                        "message", "매장 위치 정보를 확인할 수 없어 인증할 수 없습니다."
                ));
            }

            StoreCoordinates coordinates = storeCoordinates.get();
            double distanceMeters = haversine(
                    request.getLatitude(), request.getLongitude(),
                    coordinates.latitude(), coordinates.longitude());
            if (!Double.isFinite(distanceMeters)
                    || distanceMeters > MAX_LOCATION_VERIFICATION_DISTANCE_METERS) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "매장 50m 이내에서 인증해주세요."
                ));
            }

            String industry = request.getIndustry();
            if (industry == null || industry.isBlank()) {
                industry = firebaseService.findIndustryByStoreName(request.getStoreName());
            }
            // 💡 절약 금액 = 참가격(시장 평균가) − 결제가 (ReferencePrices, 메뉴 매칭 우선)
            long savedAmount = ReferencePrices.savedAmount(
                    request.getMenu(), industry, request.getPrice());
            // 클라이언트가 보낸 거리는 신뢰하지 않고 서버 계산값만 저장합니다.
            request.setVerificationDistanceMeters(distanceMeters);
            String visitId = firebaseService.saveVisit(firebaseUid, request, savedAmount);
            log.info("[VisitController] 방문 인증 완료 - id: {}, savedAmount: {}", visitId, savedAmount);
            return ResponseEntity.ok(Map.of(
                "success", true,
                "id", visitId,
                "savedAmount", savedAmount,
                "verificationMethod", LOCATION_VERIFICATION,
                "verificationDistanceMeters", Math.round(distanceMeters)
            ));
        } catch (Exception e) {
            log.error("[VisitController] 방문 인증 저장 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "방문 인증 저장 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    private boolean isValidLatitude(Double value) {
        return value != null && Double.isFinite(value) && value >= -90 && value <= 90 && value != 0;
    }

    private boolean isValidLongitude(Double value) {
        return value != null && Double.isFinite(value) && value >= -180 && value <= 180 && value != 0;
    }

    private double haversine(double lat1, double lng1, double lat2, double lng2) {
        final double earthRadiusMeters = 6_371_000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return earthRadiusMeters * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}
