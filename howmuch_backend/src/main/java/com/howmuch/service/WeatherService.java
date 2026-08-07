package com.howmuch.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;

/**
 * 기상청 단기예보 조회 서비스 (공공데이터포털).
 * WEATHER_API_KEY 환경변수로만 키 주입. 미설정 시 안전 실패(available=false).
 */
@Slf4j
@Service
public class WeatherService {

    private final String weatherApiKey;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public WeatherService(@Value("${weather.api-key:}") String weatherApiKey,
                          @Value("${weather.timeout-ms:10000}") int timeoutMs) {
        this.weatherApiKey = weatherApiKey;
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(timeoutMs);
        factory.setReadTimeout(timeoutMs);
        this.restTemplate = new RestTemplate(factory);
    }

    /**
     * 현재 날씨 요약 조회 (기상청 단기예보 getVilageFcst).
     * @param nx 격자 X (서울 60)
     * @param ny 격자 Y (서울 127)
     * @return weather(한글 요약), temp(기온), available(조회 성공 여부)
     */
    public Map<String, Object> getCurrentWeather(int nx, int ny) {
        Map<String, Object> result = new HashMap<>();
        if (weatherApiKey == null || weatherApiKey.isBlank()) {
            log.warn("WEATHER_API_KEY 미설정 — 날씨 조회 불가");
            result.put("weather", "알 수 없음");
            result.put("temp", null);
            result.put("available", false);
            return result;
        }

        try {
            LocalDateTime now = LocalDateTime.now();
            String baseDate = now.format(DateTimeFormatter.ofPattern("yyyyMMdd"));
            String baseTime = latestBaseTime(now);

            // 포털 키 2종 모두 지원: Encoding 키(% 포함)는 그대로, Decoding 키는 인코딩해서 전달
            // (Decoding 키의 '+'는 쿼리에서 공백으로 깨지고, Encoding 키를 또 인코딩하면 %25 이중 인코딩됨)
            String serviceKey = weatherApiKey.contains("%")
                    ? weatherApiKey
                    : URLEncoder.encode(weatherApiKey, StandardCharsets.UTF_8);
            String url = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst"
                    + "?serviceKey=" + serviceKey
                    + "&numOfRows=100&pageNo=1&dataType=JSON"
                    + "&base_date=" + baseDate
                    + "&base_time=" + baseTime
                    + "&nx=" + nx + "&ny=" + ny;

            // URI 객체로 전달해 RestTemplate의 재인코딩(이스케이프) 방지
            String response = restTemplate.getForObject(URI.create(url), String.class);
            JsonNode root = objectMapper.readTree(response);
            JsonNode items = root.path("response").path("body").path("items").path("item");

            String sky = null;
            String pty = null;
            String temp = null;

            for (JsonNode item : items) {
                String category = item.path("category").asText();
                String fcstValue = item.path("fcstValue").asText();
                switch (category) {
                    case "SKY" -> sky = fcstValue;
                    case "PTY" -> pty = fcstValue;
                    case "TMP" -> temp = fcstValue;
                    default -> { }
                }
            }

            result.put("weather", describeWeather(sky, pty));
            result.put("temp", temp != null ? Integer.parseInt(temp) : null);
            result.put("skyCode", sky);
            result.put("ptyCode", pty);
            result.put("available", true);
            result.put("updatedAt", java.time.Instant.now().toString());
            return result;
        } catch (Exception e) {
            log.error("기상청 API 호출 중 오류 발생: ", e);
            result.put("weather", "알 수 없음");
            result.put("temp", null);
            result.put("available", false);
            return result;
        }
    }

    /** 현재 시각 기준 가장 최근 발표 시각 (02,05,08,11,14,17,20,23) */
    private String latestBaseTime(LocalDateTime now) {
        int hour = now.getHour();
        int[] times = {2, 5, 8, 11, 14, 17, 20, 23};
        int base = 2;
        for (int t : times) {
            if (hour >= t) base = t;
        }
        return String.format("%02d00", base);
    }

    /** 하늘상태(SKY) + 강수형태(PTY) → 한글 날씨 요약 */
    private String describeWeather(String sky, String pty) {
        if (pty != null) {
            switch (pty) {
                case "1": return "비";
                case "2": return "비/눈";
                case "3": return "눈";
                case "4": return "소나기";
                default: break;
            }
        }
        if (sky != null) {
            switch (sky) {
                case "1": return "맑음";
                case "3": return "구름많음";
                case "4": return "흐림";
                default: break;
            }
        }
        return "알 수 없음";
    }
}
