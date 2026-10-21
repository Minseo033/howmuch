package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import com.howmuch.diagnostics.CatalogTiming;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import lombok.extern.slf4j.Slf4j;

import java.util.List;
import java.util.Map;
import java.util.Collections;
import java.util.HashMap;
import java.util.Objects;

/**
 * 착한가격업소(공공데이터) + 사용자 제보 매장 조회 API.
 * 기존 TestController(/api/test/*)에서 프로덕션 경로(/api/stores/*)로 승격.
 */
@RestController
@RequestMapping("/api/stores")
@Slf4j
public class StoresController {

    /** 범위 조회 결과가 상한으로 잘렸음을 알리는 응답 헤더(CORS 노출은 WebConfig에서 설정) */
    public static final String STORES_TRUNCATED_HEADER = "X-Stores-Truncated";

    private final FirebaseService firebaseService;
    private volatile MapCatalog cachedMapCatalog;

    private record MapCatalog(String sourceEtag, List<Map<String, Object>> source,
                              List<Map<String, Object>> stores, String etag) {}

    public StoresController(FirebaseService firebaseService) {
        this.firebaseService = firebaseService;
    }

    /** 전체 매장 데이터 (인메모리 캐시, gzip 압축 응답) */
    @GetMapping("/all")
    public ResponseEntity<?> getAllStores(@RequestHeader(value = "If-None-Match", required = false) String ifNoneMatch) {
        try {
            // Revalidation ensures an approved correction is not hidden behind a five-minute fresh cache.
            FirebaseService.PublicStoreCatalog catalog = firebaseService.getPublicStoreCatalog();
            String etag = catalog.etag();
            if (etag != null && ifNoneMatch != null && java.util.Arrays.stream(ifNoneMatch.split(","))
                    .map(String::trim).map(value -> value.startsWith("W/") ? value.substring(2) : value)
                    .anyMatch(value -> value.equals(etag) || value.equals("*"))) {
                return ResponseEntity.status(304).eTag(etag).cacheControl(CacheControl.noCache().cachePublic()).build();
            }
            return ResponseEntity.ok()
                    .cacheControl(CacheControl.noCache().cachePublic())
                    .eTag(etag)
                    .body(catalog.stores());
        } catch (Exception e) {
            log.error("[StoresController] 전체 매장 조회 오류", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false, "message", "매장 목록을 불러오지 못했습니다."));
        }
    }

    /** Nationwide map/search data; source-backed hours load with the existing detail endpoint. */
    @GetMapping("/catalog")
    public ResponseEntity<?> getMapCatalog(@RequestHeader(value = "If-None-Match", required = false) String ifNoneMatch) {
        try {
            MapCatalog catalog = mapCatalog(firebaseService.getPublicStoreCatalog());
            String etag = catalog.etag();
            if (etag != null && ifNoneMatch != null && java.util.Arrays.stream(ifNoneMatch.split(","))
                    .map(String::trim).map(value -> value.startsWith("W/") ? value.substring(2) : value)
                    .anyMatch(value -> value.equals(etag) || value.equals("*"))) {
                return ResponseEntity.status(304).eTag(etag).cacheControl(CacheControl.noCache().cachePublic()).build();
            }
            return ResponseEntity.ok().cacheControl(CacheControl.noCache().cachePublic())
                    .eTag(etag).body(catalog.stores());
        } catch (Exception exception) {
            log.warn("지도 매장 목록 조회 실패: {}", exception.getClass().getSimpleName());
            return ResponseEntity.status(503).body(Map.of(
                    "success", false, "message", "매장 목록을 불러오지 못했습니다."));
        }
    }

    private MapCatalog mapCatalog(FirebaseService.PublicStoreCatalog source) {
        MapCatalog cached = cachedMapCatalog;
        if (cached != null && cached.source() == source.stores()
                && Objects.equals(cached.sourceEtag(), source.etag())) {
            CatalogTiming.map("hit");
            return cached;
        }
        long waitStarted = System.nanoTime();
        synchronized (this) {
            CatalogTiming.record("map_wait", waitStarted);
            cached = cachedMapCatalog;
            if (cached != null && cached.source() == source.stores()
                    && Objects.equals(cached.sourceEtag(), source.etag())) {
                CatalogTiming.map("shared");
                return cached;
            }
            long buildStarted = System.nanoTime();
            List<Map<String, Object>> stores = source.stores().stream().map(store -> {
                Map<String, Object> copy = new HashMap<>(store);
                copy.remove("openingHours");
                return Collections.unmodifiableMap(copy);
            }).toList();
            String etag = source.etag() == null ? null
                    : source.etag().substring(0, source.etag().length() - 1) + "-map-v1\"";
            cached = new MapCatalog(source.etag(), source.stores(), stores, etag);
            cachedMapCatalog = cached;
            CatalogTiming.record("map_build", buildStarted);
            CatalogTiming.map("miss");
            return cached;
        }
    }

    /** 화면 범위(Bounds) 내 매장 조회: /api/stores/bounds?minLat=37.5&maxLat=37.6&minLng=126.9&maxLng=127.0 */
    @GetMapping("/{storeId}")
    public ResponseEntity<?> getStore(@PathVariable String storeId) {
        if (storeId == null || storeId.isBlank() || storeId.length() > 200 || storeId.contains("/")) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "매장 식별자를 확인해주세요."));
        }
        try {
            Map<String, Object> store = firebaseService.getStoreById(storeId);
            if (store == null && firebaseService.isStoreCatalogWarmingUp()) {
                // BE-CORE-7: 시작 직후 목록을 불러오는 중에는 "없음"으로 확정하지 않습니다.
                return ResponseEntity.status(503).header("Retry-After", "5").body(Map.of(
                        "success", false, "message", "매장 정보를 준비하고 있어요. 잠시 후 다시 시도해주세요."));
            }
            return store == null ? ResponseEntity.status(404).body(Map.of("success", false, "message", "매장을 찾을 수 없습니다."))
                    : ResponseEntity.ok().cacheControl(CacheControl.noCache()).body(store);
        } catch (Exception exception) {
            log.warn("매장 상세 조회 실패: {}", exception.getClass().getSimpleName());
            return ResponseEntity.status(503).body(Map.of("success", false, "message", "매장 정보를 불러오지 못했습니다. 다시 시도해주세요."));
        }
    }

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
            // 계약 C6: 중심 거리순 1,200곳 제한. 잘렸으면 X-Stores-Truncated: true 헤더로 알립니다.
            FirebaseService.BoundsResult result = firebaseService.getStoresInBoundsPage(minLat, maxLat, minLng, maxLng);
            if (result == null) {
                return ResponseEntity.ok(List.of());
            }
            ResponseEntity.BodyBuilder response = ResponseEntity.ok();
            if (result.truncated()) response.header(STORES_TRUNCATED_HEADER, "true");
            return response.body(result.stores());
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
