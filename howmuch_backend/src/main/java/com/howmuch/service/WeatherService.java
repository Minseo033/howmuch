package com.howmuch.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Function;

/**
 * 기상청 단기예보 조회 서비스 (공공데이터포털).
 * WEATHER_API_KEY 환경변수로만 키 주입. 미설정 시 안전 실패(available=false).
 *
 * 신빙성 보정 사항:
 *  - 예보 슬롯(fcstDate+fcstTime)별로 값을 모은 뒤 "현재 시각과 가장 가까운 슬롯"만 사용
 *    (기존에는 리스트 마지막 슬롯(수 시간 뒤~익일) 값이 표시되던 문제)
 *  - base_time은 발표 후 제공 시작(약 +10분)까지 시차가 있으므로 15분 버퍼를 두고 계산.
 *    자정~새벽 2시에는 전날 23시 발표분을 사용하도록 날짜 역행 처리.
 *  - 사용자 lat/lng를 기상청 격자(nx, ny)로 변환해 지역 날씨를 조회 (서울 고정 아님).
 *  - 날씨는 추천의 보조 정보다. 연결·읽기 대기를 각각 최대 3초로 제한하고, 같은 격자·발표 시각의
 *    결과는 30분, 실패는 2분 동안 재사용해 기상청 지연이 추천 응답을 막지 않게 한다.
 */
@Slf4j
@Service
public class WeatherService {

    private final String weatherApiKey;
    private final Function<URI, String> forecastFetcher;
    private final Function<URI, String> fallbackFetcher;
    private final Clock clock;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final ConcurrentHashMap<String, CachedWeather> cache = new ConcurrentHashMap<>();
    private final ExecutorService refreshExecutor;
    private final Object refreshLock = new Object();
    // Only accepted/running refreshes live here; the executor bounds their total count.
    private final Map<String, Object> inFlight = new HashMap<>();
    private boolean closed;

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("yyyyMMdd");
    private static final DateTimeFormatter TIME_FMT = DateTimeFormatter.ofPattern("HHmm");

    /** 단기예보 발표 시각 (02,05,08,11,14,17,20,23) */
    private static final int[] BASE_HOURS = {2, 5, 8, 11, 14, 17, 20, 23};

    /** 발표 후 API 제공까지의 지연 버퍼 (분) */
    private static final int PUBLISH_DELAY_MINUTES = 15;

    /** 기상청 예보 시각과 사용자가 보는 한국 현지 시각을 맞춘다. */
    private static final ZoneId KST = ZoneId.of("Asia/Seoul");

    /** 추천 응답을 날씨 때문에 오래 붙잡지 않도록 연결·응답 대기 상한을 둔다. */
    static final int MIN_TIMEOUT_MS = 500;
    static final int MAX_TIMEOUT_MS = 3000;
    static final long SUCCESS_TTL_MS = 30 * 60_000L;
    static final long FAILURE_TTL_MS = 2 * 60_000L;
    private static final int MAX_CACHE_ENTRIES = 512;

    private record CachedWeather(Map<String, Object> value, long expiresAtMillis) {}
    private record WeatherRequest(double lat, double lng, int[] grid, LocalDateTime base, String key) {}
    private record ForecastFetch(Map<String, Object> value, boolean retryOlderBase) {}

    // 테스트용 생성자가 함께 있으므로 Spring이 쓸 생성자를 명시한다(없으면 서버가 시작되지 않는다).
    @Autowired
    public WeatherService(@Value("${weather.api-key:}") String weatherApiKey,
                          @Value("${weather.timeout-ms:2000}") int timeoutMs) {
        this(
                weatherApiKey,
                restTemplateFetcher(effectiveTimeoutMs(timeoutMs)),
                restTemplateFetcher(effectiveTimeoutMs(timeoutMs)),
                Clock.system(KST));
    }

    /** 테스트에서 외부 호출과 시계를 바꿔 끼우기 위한 생성자. */
    WeatherService(String weatherApiKey, Function<URI, String> forecastFetcher, Clock clock) {
        this(weatherApiKey, forecastFetcher, null, clock);
    }

    /** 테스트에서 기상청과 보조 공급원을 각각 바꿔 끼우기 위한 생성자. */
    WeatherService(String weatherApiKey,
                   Function<URI, String> forecastFetcher,
                   Function<URI, String> fallbackFetcher,
                   Clock clock) {
        this(weatherApiKey, forecastFetcher, fallbackFetcher, clock, newRefreshExecutor());
    }

    /** Controlled executor for deterministic tests; owned and shut down by this service. */
    WeatherService(String weatherApiKey,
                   Function<URI, String> forecastFetcher,
                   Function<URI, String> fallbackFetcher,
                   Clock clock,
                   ExecutorService refreshExecutor) {
        this.weatherApiKey = weatherApiKey;
        this.forecastFetcher = forecastFetcher;
        this.fallbackFetcher = fallbackFetcher;
        this.clock = clock.withZone(KST);
        this.refreshExecutor = refreshExecutor;
    }

    private static ExecutorService newRefreshExecutor() {
        AtomicInteger sequence = new AtomicInteger();
        return new ThreadPoolExecutor(2, 2, 0L, TimeUnit.MILLISECONDS,
                new ArrayBlockingQueue<>(32), task -> {
                    Thread thread = new Thread(task, "weather-refresh-" + sequence.incrementAndGet());
                    thread.setDaemon(true);
                    return thread;
                }, new ThreadPoolExecutor.AbortPolicy());
    }

    @PreDestroy
    public void shutdown() {
        synchronized (refreshLock) {
            closed = true;
            inFlight.clear();
        }
        refreshExecutor.shutdownNow();
    }

    static int effectiveTimeoutMs(int configuredTimeoutMs) {
        return Math.max(MIN_TIMEOUT_MS, Math.min(configuredTimeoutMs, MAX_TIMEOUT_MS));
    }

    private static Function<URI, String> restTemplateFetcher(int timeoutMs) {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(timeoutMs);
        factory.setReadTimeout(timeoutMs);
        RestTemplate restTemplate = new RestTemplate(factory);
        return uri -> restTemplate.getForObject(uri, String.class);
    }

    /**
     * 현재 날씨 요약 조회 (기상청 단기예보 getVilageFcst).
     * @param lat 사용자 위도
     * @param lng 사용자 경도
     * @return weather(한글 요약), temp(기온), available(조회 성공 여부), fcstTime(사용된 예보 시각)
     */
    public Map<String, Object> getCurrentWeather(Double lat, Double lng) {
        WeatherRequest request = requestFor(lat, lng);
        if (request == null) return unavailableWeather();
        CachedWeather cached = cache.get(request.key());
        if (isFresh(cached)) {
            return new HashMap<>(cached.value());
        }
        Map<String, Object> fetched = fetchWeather(request);
        rememberCompleted(request.key(), fetched);
        return new HashMap<>(fetched);
    }

    /**
     * Never waits for a provider. Returns a fresh cached result or an unavailable
     * result with refreshing=true only while a same-grid/base refresh is pending.
     * Expired successes are deliberately not returned as current weather.
     */
    public Map<String, Object> getCurrentWeatherIfReady(Double lat, Double lng) {
        WeatherRequest request = requestFor(lat, lng);
        if (request == null) return unavailableWeather(false);
        synchronized (refreshLock) {
            CachedWeather cached = cache.get(request.key());
            if (isFresh(cached)) {
                Map<String, Object> result = new HashMap<>(cached.value());
                result.put("refreshing", !Boolean.TRUE.equals(cached.value().get("available"))
                        && inFlight.containsKey(request.key()));
                return result;
            }
            if (inFlight.containsKey(request.key())) return unavailableWeather(true);
            if (closed) return unavailableWeather(false);
            Object token = new Object();
            inFlight.put(request.key(), token);
            try {
                refreshExecutor.execute(() -> refresh(request, token));
            } catch (RuntimeException rejected) {
                inFlight.remove(request.key(), token);
                rememberCompleted(request.key(), unavailableWeather());
                return unavailableWeather(false);
            }
            // Also supports an executor that completes synchronously in tests.
            cached = cache.get(request.key());
            if (isFresh(cached)) {
                Map<String, Object> result = new HashMap<>(cached.value());
                result.put("refreshing", !Boolean.TRUE.equals(cached.value().get("available"))
                        && inFlight.containsKey(request.key()));
                return result;
            }
            return unavailableWeather(inFlight.containsKey(request.key()));
        }
    }

    private WeatherRequest requestFor(Double lat, Double lng) {
        if (lat == null || lng == null || !Double.isFinite(lat) || !Double.isFinite(lng)
                || lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
        int[] grid = toGrid(lat, lng);
        if (grid == null) return null;
        LocalDateTime base = latestBaseDateTime(LocalDateTime.now(clock).minusMinutes(PUBLISH_DELAY_MINUTES));
        String key = base.format(DATE_FMT) + base.format(TIME_FMT) + ":" + grid[0] + ":" + grid[1];
        return new WeatherRequest(lat, lng, grid, base, key);
    }

    private boolean isFresh(CachedWeather cached) {
        return cached != null && cached.expiresAtMillis() > clock.millis()
                && (!Boolean.TRUE.equals(cached.value().get("available"))
                    || isCurrentSourceTime((String) cached.value().get("fcstTime"),
                            "OPEN_METEO".equals(cached.value().get("source"))));
    }

    /** A provider timestamp, not cache insertion time, establishes current weather. */
    private boolean isCurrentSourceTime(String timestamp, boolean openMeteo) {
        try {
            LocalDateTime sourceTime = openMeteo
                    ? LocalDateTime.parse(timestamp)
                    : LocalDateTime.of(LocalDate.parse(timestamp.substring(0, 8), DATE_FMT),
                            LocalTime.parse(timestamp.substring(8), TIME_FMT));
            LocalDateTime now = LocalDateTime.now(clock);
            return !sourceTime.isBefore(now.minusHours(1))
                    && !sourceTime.isAfter(now.plusMinutes(openMeteo ? 15 : 60));
        } catch (Exception invalid) {
            return false;
        }
    }

    private void refresh(WeatherRequest request, Object token) {
        Map<String, Object> fetched = unavailableWeather();
        try {
            fetched = fetchWeather(request);
        } catch (Exception failure) {
            log.warn("Background weather refresh failed: {}", failure.getClass().getSimpleName());
        } finally {
            synchronized (refreshLock) {
                if (inFlight.get(request.key()) == token) {
                    try {
                        rememberCompleted(request.key(), fetched);
                    } finally {
                        inFlight.remove(request.key(), token);
                    }
                }
            }
        }
    }

    private Map<String, Object> fetchWeather(WeatherRequest request) {
        String baseDate = request.base().format(DATE_FMT);
        String baseTime = request.base().format(TIME_FMT);
        LocalDateTime base = request.base();
        int[] grid = request.grid();
        Map<String, Object> fetched;
        if (weatherApiKey == null || weatherApiKey.isBlank()) {
            log.warn("WEATHER_API_KEY 미설정 — 보조 날씨 공급원으로 조회합니다");
            fetched = unavailableWeather();
        } else {
            ForecastFetch fetch = fetchForecast(baseDate, baseTime, grid);
            fetched = fetch.value();
            if (!Boolean.TRUE.equals(fetched.get("available")) && fetch.retryOlderBase()) {
                LocalDateTime previousBase = latestBaseDateTime(base.minusMinutes(1));
                log.info("최신 예보 발표분이 비어 있어 직전 발표분으로 재조회합니다 ({} {} -> {} {})",
                        baseDate, baseTime, previousBase.format(DATE_FMT), previousBase.format(TIME_FMT));
                fetched = fetchForecast(
                        previousBase.format(DATE_FMT), previousBase.format(TIME_FMT), grid).value();
            }
        }

        if (!Boolean.TRUE.equals(fetched.get("available")) && fallbackFetcher != null) {
            Map<String, Object> fallback = fetchOpenMeteo(request.lat(), request.lng());
            if (Boolean.TRUE.equals(fallback.get("available"))) {
                fetched = fallback;
            }
        }
        return fetched;
    }

    private void rememberCompleted(String key, Map<String, Object> value) {
        synchronized (refreshLock) {
            long completedAt = clock.millis();
            boolean available = Boolean.TRUE.equals(value.get("available"));
            CachedWeather existing = cache.get(key);
            // Sync routes can finish alongside an async refresh. A late failure
            // must not erase a still-current success from the other attempt.
            if (!available && existing != null
                    && Boolean.TRUE.equals(existing.value().get("available")) && isFresh(existing)) {
                return;
            }
            remember(key, value, completedAt + (available ? SUCCESS_TTL_MS : FAILURE_TTL_MS), completedAt);
        }
    }

    private void remember(String key, Map<String, Object> value, long expiresAtMillis, long nowMillis) {
        if (cache.size() >= MAX_CACHE_ENTRIES) {
            cache.entrySet().removeIf(entry -> entry.getValue().expiresAtMillis() <= nowMillis);
            if (cache.size() >= MAX_CACHE_ENTRIES) cache.clear();
        }
        cache.put(key, new CachedWeather(
                Collections.unmodifiableMap(new HashMap<>(value)), expiresAtMillis));
    }

    private ForecastFetch fetchForecast(String baseDate, String baseTime, int[] grid) {
        Map<String, Object> result = new HashMap<>();
        try {
            // 포털 키 2종 모두 지원: Encoding 키(% 포함)는 그대로, Decoding 키는 인코딩해서 전달
            // (Decoding 키의 '+'는 쿼리에서 공백으로 깨지고, Encoding 키를 또 인코딩하면 %25 이중 인코딩됨)
            String serviceKey = weatherApiKey.contains("%")
                    ? weatherApiKey
                    : URLEncoder.encode(weatherApiKey, StandardCharsets.UTF_8);
            String url = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst"
                    + "?serviceKey=" + serviceKey
                    + "&numOfRows=300&pageNo=1&dataType=JSON"
                    + "&base_date=" + baseDate
                    + "&base_time=" + baseTime
                    + "&nx=" + grid[0] + "&ny=" + grid[1];

            // URI 객체로 전달해 RestTemplate의 재인코딩(이스케이프) 방지
            String response = forecastFetcher.apply(URI.create(url));
            JsonNode root = objectMapper.readTree(response);
            JsonNode apiResponse = root.path("response");
            JsonNode responseHeader = apiResponse.path("header");
            String resultCode = responseHeader.path("resultCode").asText("unknown");
            String resultMessage = responseHeader.path("resultMsg").asText("unknown");
            JsonNode items = apiResponse.path("body").path("items").path("item");

            if (!items.isArray() || items.isEmpty()) {
                log.warn("기상청 응답에 예보 항목 없음 (base {} {}, resultCode={}, resultMsg={})",
                        baseDate, baseTime, resultCode, resultMessage);
                result.put("weather", "알 수 없음");
                result.put("temp", null);
                result.put("available", false);
                return new ForecastFetch(result, true);
            }

            // 슬롯(fcstDate+fcstTime)별로 SKY/PTY/TMP를 수집
            Map<String, Map<String, String>> slots = new HashMap<>();
            for (JsonNode item : items) {
                String fcstDate = item.path("fcstDate").asText("");
                String fcstTime = item.path("fcstTime").asText("");
                String category = item.path("category").asText();
                String fcstValue = item.path("fcstValue").asText();
                if (fcstDate.isEmpty() || fcstTime.isEmpty()) continue;
                if (!category.equals("SKY") && !category.equals("PTY") && !category.equals("TMP")) continue;
                slots.computeIfAbsent(fcstDate + fcstTime, k -> new HashMap<>())
                        .put(category, fcstValue);
            }

            // 현재 시각과 가장 가까운 슬롯 선택 (현재~미래 우선, 없으면 가장 최근 과거)
            LocalDateTime now = LocalDateTime.now(clock);
            String bestKey = selectClosestForecastKey(slots, now);

            Map<String, String> chosen = bestKey != null ? slots.get(bestKey) : null;
            if (chosen == null || chosen.isEmpty() || !isCurrentSourceTime(bestKey, false)) {
                log.warn("기상청 응답에서 유효 슬롯 선택 실패");
                result.put("weather", "알 수 없음");
                result.put("temp", null);
                result.put("available", false);
                return new ForecastFetch(result, true);
            }

            String sky = chosen.get("SKY");
            String pty = chosen.get("PTY");
            String temp = chosen.get("TMP");

            Integer parsedTemp = parseTemp(temp);
            if (parsedTemp == null) {
                log.warn("기상청 응답에서 기온 값 누락 (base {} {}, slot {})", baseDate, baseTime, bestKey);
                result.put("weather", "알 수 없음");
                result.put("temp", null);
                result.put("available", false);
                return new ForecastFetch(result, true);
            }

            result.put("weather", describeWeather(sky, pty));
            result.put("temp", parsedTemp);
            result.put("skyCode", sky);
            result.put("ptyCode", pty);
            result.put("fcstTime", bestKey);
            result.put("available", true);
            result.put("updatedAt", java.time.Instant.now(clock).toString());
            return new ForecastFetch(result, false);
        } catch (Exception e) {
            log.warn("기상청 API 호출 실패: {}", e.getClass().getSimpleName());
            result.put("weather", "알 수 없음");
            result.put("temp", null);
            result.put("available", false);
            return new ForecastFetch(result, false);
        }
    }

    /** 기상청이 NO_DATA 또는 일시 오류를 반환할 때 현재 기온을 보완한다. */
    private Map<String, Object> fetchOpenMeteo(Double lat, Double lng) {
        try {
            String url = "https://api.open-meteo.com/v1/forecast"
                    + "?latitude=" + lat
                    + "&longitude=" + lng
                    + "&current=temperature_2m,weather_code"
                    + "&timezone=Asia%2FSeoul";
            String response = fallbackFetcher.apply(URI.create(url));
            JsonNode current = objectMapper.readTree(response).path("current");
            JsonNode temperatureNode = current.path("temperature_2m");
            if (!temperatureNode.isNumber() || !Double.isFinite(temperatureNode.doubleValue())
                    || !isCurrentSourceTime(current.path("time").asText(""), true)) {
                log.warn("보조 날씨 응답에서 현재 기온 누락");
                return unavailableWeather();
            }

            Map<String, Object> result = new HashMap<>();
            result.put("weather", describeWmoWeather(current.path("weather_code").asInt(-1)));
            result.put("temp", (int) Math.round(temperatureNode.doubleValue()));
            result.put("fcstTime", current.path("time").asText(""));
            result.put("available", true);
            result.put("source", "OPEN_METEO");
            result.put("updatedAt", java.time.Instant.now(clock).toString());
            log.info("기상청 예보를 보조 날씨 공급원으로 복구했습니다");
            return result;
        } catch (Exception e) {
            log.warn("보조 날씨 API 호출 실패: {}", e.getClass().getSimpleName());
            return unavailableWeather();
        }
    }

    private static Map<String, Object> unavailableWeather(boolean refreshing) {
        Map<String, Object> result = unavailableWeather();
        result.put("refreshing", refreshing);
        return result;
    }

    private static Map<String, Object> unavailableWeather() {
        Map<String, Object> result = new HashMap<>();
        result.put("weather", "알 수 없음");
        result.put("temp", null);
        result.put("available", false);
        return result;
    }

    static String describeWmoWeather(int code) {
        if (code == 0) return "맑음";
        if (code == 1) return "대체로 맑음";
        if (code == 2) return "구름 조금";
        if (code == 3) return "흐림";
        if (code == 45 || code == 48) return "안개";
        if (code >= 51 && code <= 57) return "이슬비";
        if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return "비";
        if ((code >= 71 && code <= 77) || code == 85 || code == 86) return "눈";
        if (code >= 95 && code <= 99) return "천둥번개";
        return "알 수 없음";
    }

    /**
     * 기준 시각 이하의 가장 최근 발표 시각 (02,05,08,11,14,17,20,23).
     * 자정~새벽 2시(발표 전)에는 전날 23시 발표분으로 역행한다.
     */
    static LocalDateTime latestBaseDateTime(LocalDateTime effective) {
        LocalDate date = effective.toLocalDate();
        int hour = effective.getHour();
        int base = -1;
        for (int t : BASE_HOURS) {
            if (hour >= t) base = t;
        }
        if (base < 0) {
            // 당일 첫 발표(02시) 전 → 전날 23시 발표분
            return LocalDateTime.of(date.minusDays(1), LocalTime.of(23, 0));
        }
        return LocalDateTime.of(date, LocalTime.of(base, 0));
    }

    static String selectClosestForecastKey(
            Map<String, Map<String, String>> slots, LocalDateTime now) {
        String bestFutureKey = null;
        LocalDateTime bestFutureTime = null;
        String bestPastKey = null;
        LocalDateTime bestPastTime = null;

        for (String key : slots.keySet()) {
            LocalDateTime slotTime;
            try {
                if (key == null || key.length() != 12) continue;
                slotTime = LocalDateTime.of(
                        LocalDate.parse(key.substring(0, 8), DATE_FMT),
                        LocalTime.parse(key.substring(8), TIME_FMT));
            } catch (Exception ignored) {
                continue;
            }

            if (!slotTime.isBefore(now)) {
                if (bestFutureTime == null || slotTime.isBefore(bestFutureTime)) {
                    bestFutureKey = key;
                    bestFutureTime = slotTime;
                }
            } else if (bestPastTime == null || slotTime.isAfter(bestPastTime)) {
                bestPastKey = key;
                bestPastTime = slotTime;
            }
        }
        return bestFutureKey != null ? bestFutureKey : bestPastKey;
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

    /** TMP 값 파싱 ("34", "-5", 드물게 "34.0" 형태 모두 허용) */
    private Integer parseTemp(String temp) {
        if (temp == null) return null;
        try {
            double parsed = Double.parseDouble(temp.trim());
            if (!Double.isFinite(parsed) || parsed < Integer.MIN_VALUE || parsed > Integer.MAX_VALUE) return null;
            return (int) Math.round(parsed);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /**
     * 위경도 → 기상청 단기예보 격자(nx, ny) 변환.
     * 기상청 공개 알고리즘 (Lambert Conformal Conic 투영, 5km 격자).
     * 변환 실패/범위 밖이면 null을 반환합니다.
     */
    private int[] toGrid(double lat, double lng) {
        try {
            double RE = 6371.00877;   // 지구 반경(km)
            double GRID = 5.0;        // 격자 간격(km)
            double SLAT1 = 30.0;
            double SLAT2 = 60.0;
            double OLON = 126.0;      // 기준점 경도
            double OLAT = 38.0;       // 기준점 위도
            double XO = 43;           // 기준점 X좌표
            double YO = 136;          // 기준점 Y좌표

            double DEGRAD = Math.PI / 180.0;
            double re = RE / GRID;
            double slat1 = SLAT1 * DEGRAD;
            double slat2 = SLAT2 * DEGRAD;
            double olon = OLON * DEGRAD;
            double olat = OLAT * DEGRAD;

            double sn = Math.tan(Math.PI * 0.25 + slat2 * 0.5) / Math.tan(Math.PI * 0.25 + slat1 * 0.5);
            sn = Math.log(Math.cos(slat1) / Math.cos(slat2)) / Math.log(sn);
            double sf = Math.tan(Math.PI * 0.25 + slat1 * 0.5);
            sf = Math.pow(sf, sn) * Math.cos(slat1) / sn;
            double ro = Math.tan(Math.PI * 0.25 + olat * 0.5);
            ro = re * sf / Math.pow(ro, sn);

            double ra = Math.tan(Math.PI * 0.25 + lat * DEGRAD * 0.5);
            ra = re * sf / Math.pow(ra, sn);
            double theta = lng * DEGRAD - olon;
            if (theta > Math.PI) theta -= 2.0 * Math.PI;
            if (theta < -Math.PI) theta += 2.0 * Math.PI;
            theta *= sn;

            int nx = (int) Math.floor(ra * Math.sin(theta) + XO + 0.5);
            int ny = (int) Math.floor(ro - ra * Math.cos(theta) + YO + 0.5);

            // 한국 영토 대략 범위 밖이면 기본값
            if (nx < 1 || nx > 200 || ny < 1 || ny > 250) {
                return null;
            }
            return new int[]{nx, ny};
        } catch (Exception e) {
            return null;
        }
    }
}
