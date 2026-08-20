package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.GeminiService;
import com.howmuch.service.SimpleRateLimiter;
import com.howmuch.service.WeatherService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 오늘의 픽 + AI 루트 추천 API.
 * GET /api/recommendation/todays-pick?lat=..&lng=.. : 날씨 기반 오늘의 픽
 * GET /api/recommendation/route?lat=..&lng=..      : AI 최적 동선 추천
 */
@Slf4j
@RestController
@RequestMapping("/api/recommendation")
@RequiredArgsConstructor
public class RecommendationController {

    private final WeatherService weatherService;
    private final FirebaseService firebaseService;
    private final GeminiService geminiService;
    private final SimpleRateLimiter rateLimiter;

    /** 로그인 여부와 무관하게 공개 화면에서 쓰이므로 IP/UID별 호출량을 제한합니다. */
    @Value("${recommendation.route.max-per-hour:20}")
    private int maxRouteRequestsPerHour;

    /** 오늘의 픽 (GET /api/recommendation/todays-pick) */
    @GetMapping("/todays-pick")
    public ResponseEntity<?> getTodaysPick(@RequestParam(required = false) Double lat,
                                           @RequestParam(required = false) Double lng) {
        ResponseEntity<?> coordinateError = validateCoordinates(lat, lng);
        if (coordinateError != null) return coordinateError;
        try {
            // 기상청 단기예보 (사용자 위치 → 격자 변환, 없으면 서울 기본)
            Map<String, Object> weather = weatherService.getCurrentWeather(lat, lng);
            String weatherText = (String) weather.getOrDefault("weather", "알 수 없음");
            Integer temp = (Integer) weather.get("temp");

            List<Map<String, Object>> picks = firebaseService.getTodaysPicks(weatherText, temp, lat, lng);

            Map<String, Object> result = new HashMap<>();
            result.put("weather", weatherText);
            result.put("temp", temp);
            result.put("fcstTime", weather.get("fcstTime"));
            result.put("weatherAvailable", weather.getOrDefault("available", false));
            result.put("picks", picks);
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("[RecommendationController] 오늘의 픽 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "오늘의 픽 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** AI 루트 추천 (GET /api/recommendation/route) */
    @GetMapping("/route")
    public ResponseEntity<?> getRoute(@RequestParam(required = false) Double lat,
                                      @RequestParam(required = false) Double lng,
                                      HttpServletRequest httpRequest) {
        ResponseEntity<?> coordinateError = validateCoordinates(lat, lng);
        if (coordinateError != null) return coordinateError;
        String uid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        String key = uid != null && !uid.isBlank()
                ? "route:user:" + uid
                : "route:ip:" + clientAddress(httpRequest);
        if (!rateLimiter.tryAcquire(key, maxRouteRequestsPerHour, 3_600_000L)) {
            return ResponseEntity.status(429).body(Map.of(
                    "success", false,
                    "message", "추천 루트 요청이 너무 많습니다. 잠시 후 다시 시도해주세요."
            ));
        }
        try {
            Map<String, Object> weather = weatherService.getCurrentWeather(lat, lng);
            String weatherText = (String) weather.getOrDefault("weather", "알 수 없음");
            Integer temp = (Integer) weather.get("temp");

            List<Map<String, Object>> picks = firebaseService.getTodaysPicks(weatherText, temp, lat, lng);
            String routeText = geminiService.getRouteRecommendation(picks);

            Map<String, Object> result = new HashMap<>();
            result.put("route", routeText);
            result.put("weather", weatherText);
            result.put("temp", temp);
            result.put("fcstTime", weather.get("fcstTime"));
            result.put("picks", picks);
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("[RecommendationController] 루트 추천 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "루트 추천 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    private String clientAddress(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr() != null ? request.getRemoteAddr() : "unknown";
    }

    private ResponseEntity<?> validateCoordinates(Double lat, Double lng) {
        if ((lat == null) != (lng == null)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "위도와 경도를 함께 입력해주세요."
            ));
        }
        if (lat != null && (!Double.isFinite(lat) || !Double.isFinite(lng)
                || lat < -90 || lat > 90 || lng < -180 || lng > 180)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "message", "올바른 위치 좌표를 입력해주세요."
            ));
        }
        return null;
    }
}
