package com.howmuch.service;

import org.junit.jupiter.api.Test;

import java.net.URI;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Function;

import static org.assertj.core.api.Assertions.assertThat;

class WeatherServiceTest {

    private static final double SEOUL_LAT = 37.5665;
    private static final double SEOUL_LNG = 126.9780;

    /** 테스트 안에서 시간을 앞으로 돌릴 수 있는 시계 */
    private static final class MutableClock extends Clock {
        private Instant instant;
        MutableClock(Instant instant) { this.instant = instant; }
        void advanceMillis(long millis) { instant = instant.plusMillis(millis); }
        @Override public ZoneId getZone() { return ZoneId.of("Asia/Seoul"); }
        @Override public Clock withZone(ZoneId zone) { return this; }
        @Override public Instant instant() { return instant; }
    }

    private static String forecastJson() {
        return """
                {"response":{"body":{"items":{"item":[
                  {"fcstDate":"20261006","fcstTime":"1500","category":"SKY","fcstValue":"1"},
                  {"fcstDate":"20261006","fcstTime":"1500","category":"PTY","fcstValue":"0"},
                  {"fcstDate":"20261006","fcstTime":"1500","category":"TMP","fcstValue":"21"}
                ]}}}}
                """;
    }

    private static MutableClock afternoonClock() {
        // 2026-10-06 14:40 KST
        return new MutableClock(LocalDateTime.of(2026, 10, 6, 14, 40).toInstant(ZoneOffset.ofHours(9)));
    }

    @Test
    void reusesASuccessfulForecastForTheSameGridAndBaseTime() {
        AtomicInteger calls = new AtomicInteger();
        Function<URI, String> fetcher = uri -> { calls.incrementAndGet(); return forecastJson(); };
        WeatherService service = new WeatherService("test-key", fetcher, afternoonClock());

        Map<String, Object> first = service.getCurrentWeather(SEOUL_LAT, SEOUL_LNG);
        Map<String, Object> second = service.getCurrentWeather(SEOUL_LAT, SEOUL_LNG);

        assertThat(calls.get()).isEqualTo(1);
        assertThat(first.get("available")).isEqualTo(true);
        assertThat(second).isEqualTo(first);
        assertThat(second.get("temp")).isEqualTo(21);
    }

    @Test
    void remembersAFailureBrieflySoSlowForecastsDoNotBlockEveryRequest() {
        AtomicInteger calls = new AtomicInteger();
        Function<URI, String> fetcher = uri -> {
            calls.incrementAndGet();
            throw new IllegalStateException("upstream timeout");
        };
        MutableClock clock = afternoonClock();
        WeatherService service = new WeatherService("test-key", fetcher, clock);

        assertThat(service.getCurrentWeather(SEOUL_LAT, SEOUL_LNG).get("available")).isEqualTo(false);
        assertThat(service.getCurrentWeather(SEOUL_LAT, SEOUL_LNG).get("available")).isEqualTo(false);
        assertThat(calls.get()).isEqualTo(1);

        clock.advanceMillis(WeatherService.FAILURE_TTL_MS + 1);
        service.getCurrentWeather(SEOUL_LAT, SEOUL_LNG);
        assertThat(calls.get()).isEqualTo(2);
    }

    @Test
    void cachedCopiesCannotBeMutatedByCallers() {
        WeatherService service = new WeatherService("test-key", uri -> forecastJson(), afternoonClock());

        service.getCurrentWeather(SEOUL_LAT, SEOUL_LNG).put("weather", "변조");

        assertThat(service.getCurrentWeather(SEOUL_LAT, SEOUL_LNG).get("weather")).isEqualTo("맑음");
    }

    @Test
    void clampsTheConfiguredTimeoutSoWeatherCannotOutlastTheApp() {
        assertThat(WeatherService.effectiveTimeoutMs(10_000)).isEqualTo(WeatherService.MAX_TIMEOUT_MS);
        assertThat(WeatherService.effectiveTimeoutMs(50)).isEqualTo(WeatherService.MIN_TIMEOUT_MS);
        assertThat(WeatherService.effectiveTimeoutMs(2_000)).isEqualTo(2_000);
    }

    @Test
    void usesPreviousDay23BaseBeforeTheFirstDailyForecastIsPublished() {
        LocalDateTime base = WeatherService.latestBaseDateTime(
                LocalDateTime.of(2026, 8, 20, 1, 45));

        assertThat(base).isEqualTo(LocalDateTime.of(2026, 8, 19, 23, 0));
    }

    @Test
    void usesLatestPublishedBaseAfterThePublicationDelay() {
        LocalDateTime base = WeatherService.latestBaseDateTime(
                LocalDateTime.of(2026, 8, 19, 23, 5));

        assertThat(base).isEqualTo(LocalDateTime.of(2026, 8, 19, 23, 0));
    }

    @Test
    void selectsTheNearestFutureForecastAtLateNightAcrossDateBoundary() {
        Map<String, Map<String, String>> slots = new LinkedHashMap<>();
        slots.put("202608191500", Map.of("TMP", "31"));
        slots.put("202608192300", Map.of("TMP", "27"));
        slots.put("202608200000", Map.of("TMP", "26"));

        String selected = WeatherService.selectClosestForecastKey(
                slots, LocalDateTime.of(2026, 8, 19, 23, 20));

        assertThat(selected).isEqualTo("202608200000");
    }

    @Test
    void fallsBackToTheMostRecentPastForecastWhenNoFutureSlotExists() {
        Map<String, Map<String, String>> slots = Map.of(
                "202608191500", Map.of("TMP", "31"),
                "202608192200", Map.of("TMP", "27"));

        String selected = WeatherService.selectClosestForecastKey(
                slots, LocalDateTime.of(2026, 8, 19, 23, 20));

        assertThat(selected).isEqualTo("202608192200");
    }
}
