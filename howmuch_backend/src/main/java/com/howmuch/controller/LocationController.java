package com.howmuch.controller;

import com.howmuch.service.KakaoLocalService;
import com.howmuch.service.SimpleRateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/** Public, rate-limited location helpers. The Kakao REST credential stays server-side. */
@RestController
@RequestMapping("/api/locations")
@RequiredArgsConstructor
public class LocationController {

    private static final int MAX_REQUESTS_PER_HOUR = 120;
    private static final long ONE_HOUR_MILLIS = 3_600_000L;

    private final KakaoLocalService kakaoLocalService;
    private final SimpleRateLimiter rateLimiter;

    @GetMapping("/addresses")
    public ResponseEntity<?> searchAddresses(
            @RequestParam String q, HttpServletRequest request) {
        if (q == null || q.trim().length() < 2 || q.trim().length() > 100) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "주소 검색어는 2~100자로 입력해주세요."));
        }
        if (!allowRequest(request)) return rateLimited();
        List<String> addresses = kakaoLocalService.searchAddressSuggestions(q);
        return ResponseEntity.ok(Map.of("addresses", addresses));
    }

    @GetMapping("/region")
    public ResponseEntity<?> reverseGeocode(
            @RequestParam double lat, @RequestParam double lng, HttpServletRequest request) {
        if (!Double.isFinite(lat) || !Double.isFinite(lng)
                || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "좌표 형식이 올바르지 않습니다."));
        }
        if (!allowRequest(request)) return rateLimited();
        Map<String, String> region = kakaoLocalService.getRegionFromCoordinates(lat, lng);
        if (region == null) {
            return ResponseEntity.status(503).body(Map.of(
                    "success", false, "message", "위치 정보를 불러오지 못했습니다."));
        }
        return ResponseEntity.ok(region);
    }

    private boolean allowRequest(HttpServletRequest request) {
        String address = request.getRemoteAddr();
        if (address == null || address.length() > 64) address = "unknown";
        return rateLimiter.tryAcquire(
                "location:" + address, MAX_REQUESTS_PER_HOUR, ONE_HOUR_MILLIS);
    }

    private ResponseEntity<Map<String, Object>> rateLimited() {
        return ResponseEntity.status(429).body(Map.of(
                "success", false,
                "message", "위치 검색 요청이 너무 많습니다. 잠시 후 다시 시도해주세요."));
    }
}
