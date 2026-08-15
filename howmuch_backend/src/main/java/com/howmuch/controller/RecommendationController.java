package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import com.howmuch.service.GeminiService;
import com.howmuch.service.WeatherService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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

    /** 오늘의 픽 (GET /api/recommendation/todays-pick) */
    @GetMapping("/todays-pick")
    public ResponseEntity<?> getTodaysPick(@RequestParam(required = false) Double lat,
                                           @RequestParam(required = false) Double lng) {
        try {
            // 기상청 단기예보 (사용자 위치 → 격자 변환, 없으면 서울 기본)
            Map<String, Object> weather = weatherService.getCurrentWeather(lat, lng);
            String weatherText = (String) weather.getOrDefault("weather", "알 수 없음");
            Integer temp = (Integer) weather.get("temp");

            List<Map<String, Object>> picks = firebaseService.getTodaysPicks(weatherText, temp, lat, lng);

            Map<String, Object> result = new HashMap<>();
            result.put("weather", weatherText);
            result.put("temp", temp);
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
                                      @RequestParam(required = false) Double lng) {
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
}
