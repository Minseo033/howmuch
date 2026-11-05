package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.VisitRequest;
import com.howmuch.dto.StoreCoordinates;
import com.howmuch.dto.VisitLocationEvidence;
import com.howmuch.dto.VisitResponseDto;
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
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
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
 * POST /api/visits/receipt: 영수증 접수 — 승인 시에만 방문 기록과 서버 계산 절약액 저장
 * POST /api/visits: 영수증 없는 직접 생성은 차단 (이전 앱 호환 안내)
 */
@Slf4j
@RestController
@RequestMapping("/api/visits")
public class VisitController {

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
            @RequestParam("images") List<MultipartFile> images,
            @RequestParam(required = false) Double latitude,
            @RequestParam(required = false) Double longitude,
            @RequestParam(required = false) Double locationAccuracyMeters) {
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
            if (!isValidLatitude(latitude) || !isValidLongitude(longitude)) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false, "code", "LOCATION_REQUIRED",
                        "message", "영수증 제출 전에 매장 100m 이내에서 현재 위치를 확인해주세요."));
            }
            if (locationAccuracyMeters == null || !Double.isFinite(locationAccuracyMeters)
                    || locationAccuracyMeters < 0 || locationAccuracyMeters > VisitLocationEvidence.MAX_ACCURACY_METERS) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false, "message", "현재 위치 정확도가 낮아요. 잠시 후 다시 시도해주세요."));
            }
            boolean free = price == 0 && firebaseService.isApprovedFreeMenu(normalizedStoreId, normalizedStoreName, normalizedMenu);
            if (price < 0 || (price == 0 && !free) || price > 10_000_000L) {
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
            if (firebaseService.isClosedStore(normalizedStoreId, normalizedStoreName)) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "폐업한 매장은 방문 인증할 수 없습니다."));
            }
            // 계약 C9: 공개 목록에 있는 매장인지 먼저 확인하고, 정규 매장 ID·이름으로 저장합니다.
            Optional<Map<String, Object>> visitableStore =
                    firebaseService.findVisitableStore(normalizedStoreId, normalizedStoreName);
            if (visitableStore.isEmpty()) {
                if (firebaseService.isStoreCatalogWarmingUp()) return catalogWarmingUp();
                return ResponseEntity.status(422).body(Map.of(
                        "success", false,
                        "message", "매장 정보를 확인할 수 없어 인증할 수 없습니다. 매장 상세에서 다시 시도해주세요."));
            }
            String canonicalStoreId = String.valueOf(visitableStore.get().get("storeId"));
            Object canonicalName = visitableStore.get().get("storeName");
            String canonicalStoreName = canonicalName == null || canonicalName.toString().isBlank()
                    ? normalizedStoreName : canonicalName.toString();
            Optional<StoreCoordinates> coordinates = firebaseService.findStoreCoordinates(
                    canonicalStoreId, canonicalStoreName);
            if (coordinates.isEmpty()) {
                if (firebaseService.isStoreCatalogWarmingUp()) return catalogWarmingUp();
                return ResponseEntity.status(422).body(Map.of(
                        "success", false, "message", "매장 위치 정보를 확인할 수 없어 인증할 수 없습니다."));
            }
            double distanceMeters = haversine(latitude, longitude,
                    coordinates.get().latitude(), coordinates.get().longitude());
            if (!Double.isFinite(distanceMeters) || distanceMeters > VisitLocationEvidence.MAX_DISTANCE_METERS) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false, "message", "매장 100m 이내에서 영수증을 제출해주세요."));
            }
            VisitLocationEvidence locationEvidence = new VisitLocationEvidence(distanceMeters, locationAccuracyMeters);

            if (firebaseService.receiptVerificationExists(receiptFingerprint)
                    || firebaseService.receiptVerificationExists(legacyFingerprint)) {
                return ResponseEntity.status(409).body(Map.of(
                        "success", false, "message", "이미 제출된 영수증입니다."));
            }

            // 파일 크기와 실제 이미지 시그니처를 검증한 뒤에만 유료 OCR을 호출합니다.
            uploaded = firebaseService.uploadReportImages(firebaseUid, images);
            ReceiptOcrService.Result ocrResult = receiptOcrService.analyze(
                    receiptBytes, canonicalStoreName, normalizedMenu, price);
            if (ocrResult == null) {
                ocrResult = receiptOcrService.analyze(
                    receiptBytes, canonicalStoreName, price);
            }
            String id = firebaseService.saveReceiptVerification(
                    firebaseUid, canonicalStoreId, canonicalStoreName,
                    normalizedMenu, price, receiptFingerprint, uploaded, ocrResult, locationEvidence);
            String status = "PENDING";
            String visitId = null;
            // A committed submission may defer old-image cleanup after cancellation.
            // Keep its accepted PENDING response; do not start another asynchronous write.
            if (ocrResult != null && ocrResult.shouldAutoApprove()
                    && !Thread.currentThread().isInterrupted()) {
                try {
                    Map<String, Object> approval = firebaseService.approveReceiptVerification(id, "AUTO_OCR");
                    status = String.valueOf(approval.get("status"));
                    visitId = String.valueOf(approval.get("visitId"));
                } catch (DuplicateVisitException duplicateVisit) {
                    // 접수 직후 같은 날 다른 영수증 승인이 먼저 완료된 경우입니다. 중복 적립 대신 자동 반려합니다.
                    rejectDuplicateReceipt(id);
                    return ResponseEntity.status(409).body(Map.of(
                            "success", false, "message", duplicateVisit.getMessage()));
                } catch (Exception autoApprovalError) {
                    log.warn("OCR 자동 승인 실패, 관리자 검토로 전환합니다. receiptId={}", id, autoApprovalError);
                }
            }
            Map<String, Object> response = new java.util.HashMap<>();
            response.put("success", true);
            response.put("id", id);
            response.put("status", status);
            response.put("ocrStatus", ocrResult == null ? null : ocrResult.status());
            response.put("ocrScore", ocrResult == null ? 0 : ocrResult.score());
            if (visitId != null) response.put("visitId", visitId);
            return ResponseEntity.ok(response);
        } catch (DuplicateReceiptException | DuplicateVisitException e) {
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
        // These uploads were never accepted by a receipt. Give required compensation
        // one attempt even if cancellation was preserved, then restore that signal.
        boolean interruptedBeforeCleanup = Thread.interrupted();
        try {
            firebaseService.deleteReportImages(firebaseUid, uploaded);
        } catch (InterruptedException cleanupInterrupted) {
            Thread.currentThread().interrupt();
            log.warn("저장 실패 후 영수증 이미지 정리가 중단되었습니다.", cleanupInterrupted);
        } catch (Exception cleanupError) {
            log.warn("저장 실패 후 영수증 이미지 정리에 실패했습니다.", cleanupError);
        } finally {
            if (interruptedBeforeCleanup) Thread.currentThread().interrupt();
        }
    }

    private void rejectDuplicateReceipt(String receiptId) {
        try {
            firebaseService.rejectReceiptVerification(
                    receiptId, "같은 날 이 매장의 방문 기록이 이미 있어요.", "AUTO_DUPLICATE");
        } catch (Exception rejectError) {
            log.warn("중복 영수증 자동 반려에 실패해 관리자 검토로 남깁니다. receiptId={}", receiptId, rejectError);
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

    /** 로그인한 사용자가 본인의 방문 기록만 삭제합니다. */
    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteMyVisit(
            @PathVariable String id,
            HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        if (firebaseUid == null || firebaseUid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false, "message", "로그인이 필요합니다."));
        }
        if (id == null || id.isBlank() || id.length() > 200) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "방문 기록 ID가 올바르지 않습니다."));
        }
        try {
            firebaseService.deleteOwnedVisit(id.trim(), firebaseUid);
            return ResponseEntity.ok(Map.of("success", true, "id", id.trim()));
        } catch (java.util.NoSuchElementException e) {
            return ResponseEntity.status(404).body(Map.of(
                    "success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("[VisitController] 내 방문 기록 삭제 중 오류 발생: id={}", id, e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "방문 기록 삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
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

        if (price == 0) return ResponseEntity.ok(Map.of("referencePriceAvailable", false,
                "referencePrice", 0, "savedAmount", 0, "matchedByMenu", false,
                "source", "UNAVAILABLE", "sourceLabel", "무료 이용은 절약액을 합산하지 않아요", "basisDate", "", "sampleSize", 0));
        String industry = firebaseService.findIndustryByStoreName(storeName);
        String effectiveMenu = firebaseService.resolveMenuForSavings(null, storeName, menu, price, null);
        if (menu != null && !menu.isBlank() && (effectiveMenu == null || effectiveMenu.isBlank())) {
            return ResponseEntity.ok(Map.of(
                    "referencePriceAvailable", false,
                    "referencePrice", 0,
                    "savedAmount", 0,
                    "matchedByMenu", false,
                    "source", "UNAVAILABLE",
                    "sourceLabel", "매장 등록 메뉴·가격과 일치하지 않아 절약액을 산정하지 않아요",
                    "basisDate", "",
                    "sampleSize", 0
            ));
        }
        Optional<ReferencePrices.Estimate> estimate = firebaseService.estimateReferencePrice(
                effectiveMenu, industry, firebaseService.findAddressByStoreName(storeName));
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
     * 이전 앱의 위치 인증과 클라이언트가 주장하는 영수증 인증을 모두 차단합니다.
     * 방문 생성은 저장된 영수증을 자동/관리자 승인하는 서버 트랜잭션에서만 허용합니다.
     */
    @PostMapping
    public ResponseEntity<?> createVisit(@RequestBody(required = false) VisitRequest request,
                                         HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        if (firebaseUid == null || firebaseUid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false, "message", "인증 정보가 유효하지 않습니다."));
        }
        return ResponseEntity.status(403).body(Map.of(
                "success", false,
                "code", "RECEIPT_REQUIRED",
                "message", "방문 기록은 위치 확인과 영수증 인증 후에만 저장할 수 있습니다. 앱을 새로고침하고 영수증을 제출해주세요."));
    }

    /** BE-CORE-7: 시작 직후 매장 목록을 불러오는 중이면 422 대신 503으로 잠시 후 재시도를 안내합니다. */
    private ResponseEntity<?> catalogWarmingUp() {
        return ResponseEntity.status(503).header("Retry-After", "5").body(Map.of(
                "success", false, "message", "매장 정보를 준비하고 있어요. 잠시 후 다시 시도해주세요."));
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
