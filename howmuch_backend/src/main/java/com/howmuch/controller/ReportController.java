package com.howmuch.controller;

import com.howmuch.dto.UserReportRequest;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.KakaoLocalService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/report")
@RequiredArgsConstructor
public class ReportController {

    private final FirebaseService firebaseService;
    private final KakaoLocalService kakaoLocalService;

    @PostMapping("/store")
    public ResponseEntity<?> submitStoreReport(@RequestBody UserReportRequest report) {
        try {
            // 💡 입력된 주소를 바탕으로 위도/경도 및 지역 정보를 추출합니다.
            Map<String, Object> coords = kakaoLocalService.getCoordinatesFromAddress(report.getAddress());
            if (coords != null) {
                report.setLatitude((Double) coords.get("lat"));
                report.setLongitude((Double) coords.get("lng"));
                report.setCityProvince((String) coords.get("province"));
                report.setCityDistrict((String) coords.get("district"));
                log.info("주소 변환 성공: {} -> {}", report.getAddress(), coords);
            }

            String reportId = firebaseService.saveUserReport(report);
            return ResponseEntity.ok(Map.of(
                "success", true,
                "reportId", reportId,
                "message", "제보가 성공적으로 접수되었습니다."
            ));
        } catch (Exception e) {
            log.error("제보 저장 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                "success", false,
                "message", "제보 저장 중 오류가 발생했습니다: " + e.getMessage()
            ));
        }
    }

    @GetMapping("/my")
    public ResponseEntity<?> getMyReports(@RequestHeader("X-Firebase-Uid") String firebaseUid) {
        try {
            log.info("[ReportController] 내 제보 목록 조회 요청 - uid: {}", firebaseUid);
            java.util.List<Map<String, Object>> reports = firebaseService.getUserReports(firebaseUid);
            return ResponseEntity.ok(reports);
        } catch (Exception e) {
            log.error("[ReportController] 내 제보 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                "success", false,
                "message", "제보 목록 조회 중 오류가 발생했습니다: " + e.getMessage()
            ));
        }
    }
}
