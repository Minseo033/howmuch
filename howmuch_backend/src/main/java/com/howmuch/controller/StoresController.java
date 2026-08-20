package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.ResponseEntity;
import lombok.extern.slf4j.Slf4j;

import java.util.List;
import java.util.Map;

/**
 * 착한가격업소(공공데이터) + 사용자 제보 매장 조회 API.
 * 기존 TestController(/api/test/*)에서 프로덕션 경로(/api/stores/*)로 승격.
 */
@RestController
@RequestMapping("/api/stores")
@Slf4j
public class StoresController {

    private final FirebaseService firebaseService;

    public StoresController(FirebaseService firebaseService) {
        this.firebaseService = firebaseService;
    }

    /** 전체 매장 데이터 (인메모리 캐시, gzip 압축 응답) */
    @GetMapping("/all")
    public ResponseEntity<?> getAllStores() {
        try {
            return ResponseEntity.ok(firebaseService.getAllStores());
        } catch (Exception e) {
            log.error("[StoresController] 전체 매장 조회 오류", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "매장 목록을 불러오지 못했습니다."));
        }
    }

    /** 화면 범위(Bounds) 내 매장 조회: /api/stores/bounds?minLat=37.5&maxLat=37.6&minLng=126.9&maxLng=127.0 */
    @GetMapping("/bounds")
    public ResponseEntity<?> getStoresInBounds(
            @RequestParam double minLat, @RequestParam double maxLat,
            @RequestParam double minLng, @RequestParam double maxLng) {
        if (!isValidBounds(minLat, maxLat, minLng, maxLng)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "지도 조회 범위가 올바르지 않습니다."));
        }
        try {
            return ResponseEntity.ok(firebaseService.getStoresInBounds(minLat, maxLat, minLng, maxLng));
        } catch (Exception e) {
            log.error("[StoresController] 지도 범위 매장 조회 오류", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "매장 목록을 불러오지 못했습니다."));
        }
    }

    static boolean isValidBounds(double minLat, double maxLat, double minLng, double maxLng) {
        return Double.isFinite(minLat) && Double.isFinite(maxLat)
                && Double.isFinite(minLng) && Double.isFinite(maxLng)
                && minLat >= -90 && maxLat <= 90
                && minLng >= -180 && maxLng <= 180
                && minLat < maxLat && minLng < maxLng
                && maxLat - minLat <= 10 && maxLng - minLng <= 10;
    }

    /** 매장의 승인된 가격 변동 이력 */
    @GetMapping("/{storeId}/price-history")
    public ResponseEntity<?> getPriceHistory(
            @PathVariable String storeId,
            @RequestParam(required = false) String menu) {
        if (storeId == null || storeId.isBlank() || storeId.length() > 200
                || (menu != null && menu.length() > 100)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "매장 또는 메뉴 정보가 올바르지 않습니다."));
        }
        try {
            return ResponseEntity.ok(firebaseService.getPriceHistory(storeId, menu));
        } catch (java.util.NoSuchElementException e) {
            return ResponseEntity.status(404).body(Map.of(
                    "success", false, "message", "매장 가격 이력을 찾을 수 없습니다."));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "가격 이력을 불러오지 못했습니다."));
        }
    }
}
