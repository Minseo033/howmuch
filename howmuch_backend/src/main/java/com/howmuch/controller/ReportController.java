package com.howmuch.controller;

import com.howmuch.dto.UserReportRequest;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.KakaoLocalService;
import com.howmuch.service.SimpleRateLimiter;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;

@Slf4j
@RestController
@RequestMapping("/api/report")
@RequiredArgsConstructor
public class ReportController {

    private final FirebaseService firebaseService;
    private final KakaoLocalService kakaoLocalService;
    private final SimpleRateLimiter rateLimiter;

    @Value("${report.images.max-uploads-per-hour:20}")
    private int maxImageUploadsPerHour;

    @PostMapping(value = "/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> uploadReportImages(
            jakarta.servlet.http.HttpServletRequest httpRequest,
            @RequestParam("images") List<MultipartFile> images) {
        String reporterUid = (String) httpRequest.getAttribute(
                com.howmuch.config.SessionAuthFilter.UID_ATTRIBUTE);
        if (reporterUid != null && !reporterUid.isBlank()
                && !rateLimiter.tryAcquire(
                        "report-image:" + reporterUid,
                        maxImageUploadsPerHour,
                        3_600_000L)) {
            return ResponseEntity.status(429).body(Map.of(
                    "success", false,
                    "message", "사진 업로드 요청이 너무 많습니다. 잠시 후 다시 시도해주세요."
            ));
        }
        try {
            List<String> imageUrls = firebaseService.uploadReportImages(reporterUid, images);
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "imageUrls", imageUrls
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", e.getMessage()
            ));
        } catch (SecurityException e) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false,
                    "message", "로그인이 필요합니다."
            ));
        } catch (IllegalStateException e) {
            log.warn("제보 사진 저장소가 설정되지 않았습니다.");
            return ResponseEntity.status(503).body(Map.of(
                    "success", false,
                    "message", "사진 저장소를 준비 중입니다. 잠시 후 다시 시도해주세요."
            ));
        } catch (Exception e) {
            log.error("제보 사진 업로드 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "사진 업로드 중 오류가 발생했습니다."
            ));
        }
    }

    @PostMapping("/images/cleanup")
    public ResponseEntity<?> cleanupReportImages(
            jakarta.servlet.http.HttpServletRequest httpRequest,
            @RequestBody Map<String, Object> request) {
        String reporterUid = (String) httpRequest.getAttribute(
                com.howmuch.config.SessionAuthFilter.UID_ATTRIBUTE);
        if (reporterUid == null || reporterUid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false, "message", "로그인이 필요합니다."));
        }

        Object imageUrlsValue = request.get("imageUrls");
        if (!(imageUrlsValue instanceof List<?> imageUrlItems)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "정리할 이미지 목록이 필요합니다."));
        }
        List<String> imageUrls = imageUrlItems.stream()
                .filter(item -> item != null)
                .map(Object::toString)
                .toList();
        try {
            int deleted = firebaseService.deleteReportImages(reporterUid, imageUrls);
            return ResponseEntity.ok(Map.of("success", true, "deleted", deleted));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", e.getMessage()));
        } catch (IllegalStateException e) {
            log.warn("제보 사진 저장소가 설정되지 않았습니다.");
            return ResponseEntity.status(503).body(Map.of(
                    "success", false,
                    "message", "사진 저장소를 준비 중입니다. 잠시 후 다시 시도해주세요."));
        } catch (Exception e) {
            log.error("제보 사진 정리 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "사진 정리 중 오류가 발생했습니다."));
        }
    }

    @PostMapping("/store")
    public ResponseEntity<?> submitStoreReport(
            jakarta.servlet.http.HttpServletRequest httpRequest,
            @RequestBody UserReportRequest report) {
        // 💡 제보자 식별자는 클라이언트 입력이 아닌 인증된 세션에서만 가져옵니다 (스푸핑 방지)
        String reporterUid = (String) httpRequest.getAttribute(
                com.howmuch.config.SessionAuthFilter.UID_ATTRIBUTE);
        if (reporterUid == null || reporterUid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false, "message", "로그인이 필요합니다."));
        }
        if (report == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "제보 내용을 입력해주세요."));
        }
        report.setReporterId(reporterUid);
        try {
            ResponseEntity<?> validationError = validateReport(report);
            if (validationError != null) return validationError;
            applyCoordinates(report);

            String reportId = firebaseService.saveUserReport(report);
            return ResponseEntity.ok(Map.of(
                "success", true,
                "reportId", reportId,
                "message", "제보가 성공적으로 접수되었습니다."
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("제보 저장 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                "success", false,
                "message", "제보 저장 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    @PutMapping("/store/{id}")
    public ResponseEntity<?> updateStoreReport(
            @PathVariable String id,
            jakarta.servlet.http.HttpServletRequest httpRequest,
            @RequestBody UserReportRequest report) {
        String reporterUid = (String) httpRequest.getAttribute(
                com.howmuch.config.SessionAuthFilter.UID_ATTRIBUTE);
        if (reporterUid == null || reporterUid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false, "message", "로그인이 필요합니다."));
        }
        if (!isValidDocumentId(id)) {
            return invalidReportId();
        }
        if (report == null) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "제보 내용을 입력해주세요."));
        }

        try {
            ResponseEntity<?> validationError = validateReport(report);
            if (validationError != null) return validationError;
            applyCoordinates(report);
            firebaseService.updateUserReport(id, reporterUid, report);
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "reportId", id,
                    "message", "제보가 수정되어 다시 검토 요청되었습니다."
            ));
        } catch (NoSuchElementException e) {
            return ResponseEntity.status(404).body(Map.of(
                    "success", false, "message", "제보를 찾을 수 없습니다."));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", e.getMessage()));
        } catch (SecurityException e) {
            return ResponseEntity.status(403).body(Map.of(
                    "success", false, "message", "본인의 제보만 수정할 수 있습니다."));
        } catch (Exception e) {
            log.error("제보 수정 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "제보 수정 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    @DeleteMapping("/store/{id}")
    public ResponseEntity<?> deleteStoreReport(
            @PathVariable String id,
            jakarta.servlet.http.HttpServletRequest httpRequest) {
        String reporterUid = (String) httpRequest.getAttribute(
                com.howmuch.config.SessionAuthFilter.UID_ATTRIBUTE);
        if (reporterUid == null || reporterUid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false, "message", "로그인이 필요합니다."));
        }
        if (!isValidDocumentId(id)) {
            return invalidReportId();
        }

        try {
            return ResponseEntity.ok(firebaseService.deleteUserReport(id, reporterUid));
        } catch (NoSuchElementException e) {
            return ResponseEntity.status(404).body(Map.of(
                    "success", false, "message", "제보를 찾을 수 없습니다."));
        } catch (SecurityException e) {
            return ResponseEntity.status(403).body(Map.of(
                    "success", false, "message", "본인의 제보만 삭제할 수 있습니다."));
        } catch (IllegalStateException e) {
            log.warn("제보 사진 저장소가 설정되지 않아 삭제를 중단했습니다. reportId={}", id);
            return ResponseEntity.status(503).body(Map.of(
                    "success", false,
                    "message", "사진 저장소를 준비 중입니다. 잠시 후 다시 시도해주세요."));
        } catch (Exception e) {
            log.error("제보 삭제 중 오류 발생: reportId={}", id, e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "제보 삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."));
        }
    }

    @GetMapping("/my")
    public ResponseEntity<?> getMyReports(jakarta.servlet.http.HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(
                com.howmuch.config.SessionAuthFilter.UID_ATTRIBUTE);
        if (firebaseUid == null || firebaseUid.isBlank()) {
            return ResponseEntity.status(401).body(Map.of(
                    "success", false, "message", "로그인이 필요합니다."));
        }
        try {
            java.util.List<Map<String, Object>> reports = firebaseService.getUserReports(firebaseUid);
            return ResponseEntity.ok(reports);
        } catch (Exception e) {
            log.error("[ReportController] 내 제보 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                "success", false,
                "message", "제보 목록 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    private ResponseEntity<?> validateReport(UserReportRequest report) {
        normalizeReport(report);
        if (report.getStoreName() == null || report.getStoreName().isBlank()
                || report.getAddress() == null || report.getAddress().isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "매장명과 주소는 필수입니다."));
        }
        if (report.getStoreName().length() > 100 || report.getAddress().length() > 300) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "입력값이 허용 길이를 초과했습니다."));
        }
        if (tooLong(report.getStoreId(), 200)
                || tooLong(report.getPhoneNumber(), 30)
                || tooLong(report.getIndustry(), 100)
                || tooLong(report.getCityProvince(), 100)
                || tooLong(report.getCityDistrict(), 100)
                || tooLong(report.getMenu1(), 100)
                || tooLong(report.getMenu2(), 100)
                || tooLong(report.getMenu3(), 100)
                || tooLong(report.getMenu4(), 100)
                || tooLong(report.getPrice1(), 30)
                || tooLong(report.getPrice2(), 30)
                || tooLong(report.getPrice3(), 30)
                || tooLong(report.getPrice4(), 30)
                || tooLong(report.getChangeType(), 30)
                || tooLong(report.getReportType(), 30)
                || tooLong(report.getDescription(), 1000)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "입력값이 허용 길이를 초과했습니다."));
        }
        if (report.getReportType() != null
                && !report.getReportType().isBlank()
                && !reportTypeIsStoreInfo(report)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "올바르지 않은 제보 유형입니다."));
        }
        if (report.getChangeType() != null && !report.getChangeType().isBlank()) {
            List<String> allowedTypes = reportTypeIsStoreInfo(report)
                    ? List.of("closed", "price_mismatch", "location_wrong", "other")
                    : List.of("rise", "drop", "new", "delete");
            if (!allowedTypes.contains(report.getChangeType())) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false, "message", "올바르지 않은 가격 변동 유형입니다."));
            }
            if (!reportTypeIsStoreInfo(report)
                    && (report.getMenu1() == null || report.getMenu1().isBlank())) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false, "message", "변경된 메뉴를 입력해주세요."));
            }
            if (!reportTypeIsStoreInfo(report)
                    && !"delete".equals(report.getChangeType())
                    && (report.getPrice1() == null || report.getPrice1().isBlank())) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false, "message", "변경된 가격을 입력해주세요."));
            }
            if (!reportTypeIsStoreInfo(report) && !report.isCheckedMenuPrice()) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false, "message", "메뉴판 가격 확인 여부를 체크해주세요."));
            }
        }
        return null;
    }

    private void normalizeReport(UserReportRequest report) {
        report.setStoreName(trimToNull(report.getStoreName()));
        report.setAddress(trimToNull(report.getAddress()));
        report.setStoreId(trimToNull(report.getStoreId()));
        report.setPhoneNumber(trimToNull(report.getPhoneNumber()));
        report.setIndustry(trimToNull(report.getIndustry()));
        report.setCityProvince(trimToNull(report.getCityProvince()));
        report.setCityDistrict(trimToNull(report.getCityDistrict()));
        report.setMenu1(trimToNull(report.getMenu1()));
        report.setMenu2(trimToNull(report.getMenu2()));
        report.setMenu3(trimToNull(report.getMenu3()));
        report.setMenu4(trimToNull(report.getMenu4()));
        report.setPrice1(trimToNull(report.getPrice1()));
        report.setPrice2(trimToNull(report.getPrice2()));
        report.setPrice3(trimToNull(report.getPrice3()));
        report.setPrice4(trimToNull(report.getPrice4()));
        report.setChangeType(trimToNull(report.getChangeType()));
        report.setReportType(trimToNull(report.getReportType()));
        report.setDescription(trimToNull(report.getDescription()));
    }

    private String trimToNull(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private boolean tooLong(String value, int maxLength) {
        return value != null && value.length() > maxLength;
    }

    private boolean isValidDocumentId(String id) {
        return id != null && !id.isBlank() && id.length() <= 512 && !id.contains("/");
    }

    private ResponseEntity<?> invalidReportId() {
        return ResponseEntity.badRequest().body(Map.of(
                "success", false, "message", "제보 ID 형식이 올바르지 않습니다."));
    }

    private boolean reportTypeIsStoreInfo(UserReportRequest report) {
        return "STORE_INFO".equalsIgnoreCase(report.getReportType());
    }

    private void applyCoordinates(UserReportRequest report) throws Exception {
        Map<String, Object> coords = kakaoLocalService.getCoordinatesFromAddress(report.getAddress());
        if (coords == null) return;
        Double latitude = finiteCoordinate(coords.get("lat"), 90);
        Double longitude = finiteCoordinate(coords.get("lng"), 180);
        if (latitude == null || longitude == null
                || (latitude == 0 && longitude == 0)) {
            return;
        }
        report.setLatitude(latitude);
        report.setLongitude(longitude);
        report.setCityProvince(trimToNull(stringValue(coords.get("province"))));
        report.setCityDistrict(trimToNull(stringValue(coords.get("district"))));
    }

    private Double finiteCoordinate(Object value, double maximumAbsoluteValue) {
        if (value == null) return null;
        try {
            double parsed = Double.parseDouble(value.toString());
            return Double.isFinite(parsed) && Math.abs(parsed) <= maximumAbsoluteValue
                    ? parsed : null;
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private String stringValue(Object value) {
        return value == null ? null : value.toString();
    }
}
