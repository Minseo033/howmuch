package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.VisitRequest;
import com.howmuch.dto.VisitResponseDto;
import com.howmuch.dto.StoreCoordinates;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.ReferencePrices;
import com.howmuch.service.ReceiptOcrService;
import com.howmuch.service.SimpleRateLimiter;
import com.howmuch.service.DuplicateVisitException;
import com.howmuch.service.DuplicateReceiptException;
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
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

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
    private static final double MAX_LOCATION_VERIFICATION_DISTANCE_METERS = 100.0;
    private static final double MAX_LOCATION_ACCURACY_METERS = 50.0;

    private final FirebaseService firebaseService;
    private final ReceiptOcrService receiptOcrService;
    private final SimpleRateLimiter rateLimiter;

    @org.springframework.beans.factory.annotation.Value("${receipt.ocr.max-per-hour:10}")
    private int maxReceiptOcrRequestsPerHour = 10;

    @Autowired
    public VisitController(FirebaseService firebaseService,
                           ReceiptOcrService receiptOcrService,
                           SimpleRateLimiter rateLimiter) {
        this.firebaseService = firebaseService;
        this.receiptOcrService = receiptOcrService;
        this.rateLimiter = rateLimiter;
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
            String normalizedStoreId = storeId.trim();
            String normalizedStoreName = storeName.trim();
            String normalizedMenu = menu == null ? "" : menu.trim();
            if (normalizedStoreId.length() > 200
                    || normalizedStoreName.length() > 100
                    || normalizedMenu.length() > 100) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false, "message", "입력값이 허용 범위를 초과했습니다."));
            }
            if (price <= 0 || price > 10_000_000L) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "결제 금액을 확인해주세요."));
            }
            if (images == null || images.size() != 1) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "영수증 사진 1장을 첨부해주세요."));
            }
            byte[] receiptBytes = images.get(0).getBytes();
            String receiptFingerprint = receiptFingerprint(receiptBytes);
            String legacyFingerprint = legacyReceiptFingerprint(firebaseUid, receiptBytes);
            if (!rateLimiter.tryAcquire(
                    "receipt-ocr:" + firebaseUid,
                    maxReceiptOcrRequestsPerHour,
                    3_600_000L)) {
                return ResponseEntity.status(429).body(Map.of(
                        "success", false,
                        "message", "영수증 인증 요청이 너무 많습니다. 잠시 후 다시 시도해주세요."));
            }
            if (firebaseService.receiptVerificationExists(receiptFingerprint)
                    || firebaseService.receiptVerificationExists(legacyFingerprint)) {
                return ResponseEntity.status(409).body(Map.of(
                        "success", false, "message", "이미 제출된 영수증입니다."));
            }

            // 파일 크기와 실제 이미지 시그니처를 검증한 뒤에만 유료 OCR을 호출합니다.
            uploaded = firebaseService.uploadReportImages(firebaseUid, images);
            ReceiptOcrService.Result ocrResult = receiptOcrService.analyze(
                    receiptBytes, normalizedStoreName, price);
            String id = firebaseService.saveReceiptVerification(
                    firebaseUid, normalizedStoreId, normalizedStoreName,
                    normalizedMenu, price, receiptFingerprint, uploaded, ocrResult);
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
        } catch (DuplicateReceiptException e) {
            cleanupUploadedReceipt(firebaseUid, uploaded);
            return ResponseEntity.status(409).body(Map.of(
                    "success", false, "message", e.getMessage()));
        } catch (IllegalArgumentException e) {
            cleanupUploadedReceipt(firebaseUid, uploaded);
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", e.getMessage()));
        } catch (IllegalStateException e) {
            cleanupUploadedReceipt(firebaseUid, uploaded);
            return ResponseEntity.status(503).body(Map.of(
                    "success", false,
                    "message", "사진 저장소를 준비 중입니다. 잠시 후 다시 시도해주세요."));
        } catch (Exception e) {
            cleanupUploadedReceipt(firebaseUid, uploaded);
            log.error("영수증 인증 요청 저장 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of("success", false, "message", "영수증 인증 요청을 저장하지 못했습니다."));
        }
    }

    private void cleanupUploadedReceipt(String firebaseUid, List<String> uploaded) {
        if (uploaded == null || uploaded.isEmpty()) return;
        try {
            firebaseService.deleteReportImages(firebaseUid, uploaded);
        } catch (Exception cleanupError) {
            log.warn("저장 실패 후 영수증 이미지 정리에 실패했습니다.", cleanupError);
        }
    }

    static String receiptFingerprint(byte[] bytes) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            digest.update(bytes);
            return java.util.HexFormat.of().formatHex(digest.digest());
        } catch (Exception e) {
            throw new IllegalStateException("영수증 식별값을 만들지 못했습니다.", e);
        }
    }

    /** 8월 19일 이전에 저장된 사용자별 영수증 해시 조회용 호환 식별값입니다. */
    static String legacyReceiptFingerprint(String firebaseUid, byte[] bytes) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            digest.update(firebaseUid.getBytes(StandardCharsets.UTF_8));
            digest.update((byte) 0);
            digest.update(bytes);
            return java.util.HexFormat.of().formatHex(digest.digest());
        } catch (Exception e) {
            throw new IllegalStateException("영수증 식별값을 만들지 못했습니다.", e);
        }
    }

    /**
     * 방문 기록 목록 조회 (GET /api/visits)
     * 세션 토큰으로 인증된 유저의 Firestore 방문 기록(방문 일시, 매장명, 절약 금액 등)을 최신순으로 조회합니다.
     */
    @GetMapping
    public ResponseEntity<?> getUserVisits(HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body(Map.of(
                        "success", false, "message", "인증 정보가 유효하지 않습니다."));
            }

            List<VisitResponseDto> visits = firebaseService.getUserVisits(firebaseUid);
            return ResponseEntity.ok(visits);
        } catch (Exception e) {
            log.error("[VisitController] 방문 기록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "방문 기록 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."));
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
            return ResponseEntity.status(401).body(Map.of(
                    "success", false, "message", "인증 정보가 유효하지 않습니다."));
        }
        if (storeName == null || storeName.isBlank() || storeName.length() > 100
                || (menu != null && menu.length() > 100)
                || price < 0 || price > 10_000_000L) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "입력값이 허용 범위를 벗어났습니다."));
        }

        String industry = firebaseService.findIndustryByStoreName(storeName);
        Optional<ReferencePrices.Estimate> estimate = firebaseService.estimateReferencePrice(
                menu, industry, firebaseService.findAddressByStoreName(storeName));
        if (estimate.isEmpty()) {
            return ResponseEntity.ok(Map.of(
                    "referencePriceAvailable", false,
                    "referencePrice", 0,
                    "savedAmount", 0,
                    "matchedByMenu", false,
                    "source", "UNAVAILABLE",
                    "sourceLabel", "비교 가능한 공공 가격 데이터 없음",
                    "basisDate", "",
                    "sampleSize", 0
            ));
        }
        ReferencePrices.Estimate value = estimate.get();
        return ResponseEntity.ok(Map.of(
                "referencePriceAvailable", true,
                "referencePrice", value.referencePrice(),
                "savedAmount", ReferencePrices.savedAmount(estimate, price),
                "matchedByMenu", value.isMenuLevel(),
                "source", value.source(),
                "sourceLabel", value.label(),
                "basisDate", value.basisDate(),
                "sampleSize", value.sampleSize()
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

        if (firebaseUid == null || firebaseUid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false, "message", "인증 정보가 유효하지 않습니다."));
        }
        if (request == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "방문 인증 정보가 필요합니다."));
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
                || request.getLocationAccuracyMeters() > MAX_LOCATION_ACCURACY_METERS) {
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
                        "message", "매장 100m 이내에서 인증해주세요."
                ));
            }

            String industry = coordinates.industry();
            if (coordinates.storeId() != null && !coordinates.storeId().isBlank()) {
                request.setStoreId(coordinates.storeId());
            }
            if (coordinates.storeName() != null && !coordinates.storeName().isBlank()) {
                request.setStoreName(coordinates.storeName());
            }
            request.setIndustry(industry);
            long savedAmount = ReferencePrices.savedAmount(
                    firebaseService.estimateReferencePrice(
                            request.getMenu(), industry,
                            firebaseService.findAddressByStoreName(request.getStoreName())),
                    request.getPrice());
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
        } catch (DuplicateVisitException e) {
            return ResponseEntity.status(409).body(Map.of(
                    "success", false,
                    "message", e.getMessage()
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
