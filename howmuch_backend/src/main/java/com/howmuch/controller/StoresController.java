package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * 착한가격업소(공공데이터) + 사용자 제보 매장 조회 API.
 * 기존 TestController(/api/test/*)에서 프로덕션 경로(/api/stores/*)로 승격.
 */
@RestController
@RequestMapping("/api/stores")
public class StoresController {

    private final FirebaseService firebaseService;

    public StoresController(FirebaseService firebaseService) {
        this.firebaseService = firebaseService;
    }

    /** 전체 매장 데이터 (인메모리 캐시, gzip 압축 응답) */
    @GetMapping("/all")
    public List<Map<String, Object>> getAllStores() {
        try {
            return firebaseService.getAllStores();
        } catch (Exception e) {
            e.printStackTrace();
            return Collections.emptyList();
        }
    }

    /** 화면 범위(Bounds) 내 매장 조회: /api/stores/bounds?minLat=37.5&maxLat=37.6&minLng=126.9&maxLng=127.0 */
    @GetMapping("/bounds")
    public List<Map<String, Object>> getStoresInBounds(
            @RequestParam double minLat, @RequestParam double maxLat,
            @RequestParam double minLng, @RequestParam double maxLng) {
        try {
            return firebaseService.getStoresInBounds(minLat, maxLat, minLng, maxLng);
        } catch (Exception e) {
            e.printStackTrace();
            return Collections.emptyList();
        }
    }
}