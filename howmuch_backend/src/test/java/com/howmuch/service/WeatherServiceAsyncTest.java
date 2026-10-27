package com.howmuch.service;

import org.junit.jupiter.api.Test;

import java.net.URI;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.concurrent.AbstractExecutorService;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Function;

import static org.assertj.core.api.Assertions.assertThat;

class WeatherServiceAsyncTest {
    private static final double LAT = 37.5665;
    private static final double LNG = 126.9780;
    private static final String FORECAST = """
            {"response":{"body":{"items":{"item":[
              {"fcstDate":"20261006","fcstTime":"1500","category":"SKY","fcstValue":"1"},
              {"fcstDate":"20261006","fcstTime":"1500","category":"PTY","fcstValue":"0"},
              {"fcstDate":"20261006","fcstTime":"1500","category":"TMP","fcstValue":"21"}
            ]}}}}
            """;

    @Test
    void coldRequestReturnsBeforeAnyProviderWorkAndCompletionMakesCacheReady() {
        ManualExecutor executor = new ManualExecutor();
        AtomicInteger calls = new AtomicInteger();
        WeatherService service = service(uri -> { calls.incrementAndGet(); return FORECAST; }, clock(), executor);
        try {
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
            assertThat(calls).hasValue(0);
            assertThat(executor.tasks).hasSize(1);
            executor.runNext();
            Map<String, Object> ready = service.getCurrentWeatherIfReady(LAT, LNG);
            assertThat(ready).containsEntry("available", true).containsEntry("refreshing", false)
                    .containsEntry("temp", 21).containsEntry("fcstTime", "202610061500");
            ready.put("temp", 999);
            ready.put("available", false);
            assertThat(service.getCurrentWeatherIfReady(LAT, LNG)).containsEntry("temp", 21);
            assertThat(service.getCurrentWeather(LAT, LNG)).containsEntry("temp", 21);
            assertThat(calls).hasValue(1);
        } finally { service.shutdown(); }
    }

    @Test
    void pendingRequestsCoalesceByGridAndBaseAndDoNotShareMutableMaps() {
        ManualExecutor executor = new ManualExecutor();
        WeatherService service = service(uri -> FORECAST, clock(), executor);
        try {
            Map<String, Object> first = service.getCurrentWeatherIfReady(LAT, LNG);
            first.put("refreshing", false);
            for (int i = 0; i < 100; i++) {
                assertPending(service.getCurrentWeatherIfReady(LAT + 0.00001, LNG));
            }
            assertThat(executor.tasks).hasSize(1);
            executor.runNext();
            assertThat(service.getCurrentWeatherIfReady(LAT, LNG)).containsEntry("available", true);
        } finally { service.shutdown(); }
    }

    @Test
    void failureIsSettledUntilFailureTtlExpiresAndInflightIsReleased() {
        ManualExecutor executor = new ManualExecutor();
        MutableClock clock = clock();
        AtomicInteger calls = new AtomicInteger();
        WeatherService service = service(uri -> {
            calls.incrementAndGet();
            throw new IllegalStateException("test failure");
        }, clock, executor);
        try {
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
            executor.runNext();
            assertSettledFailure(service.getCurrentWeatherIfReady(LAT, LNG));
            assertThat(executor.tasks).isEmpty();
            clock.advance(WeatherService.FAILURE_TTL_MS - 1);
            assertSettledFailure(service.getCurrentWeatherIfReady(LAT, LNG));
            clock.advance(1);
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
            assertThat(executor.tasks).hasSize(1);
            executor.runNext();
            assertThat(calls).hasValue(2);
        } finally { service.shutdown(); }
    }

    @Test
    void rejectionReturnsImmediatelyCleansInflightAndSuppressesResubmissionUntilExpiry() {
        ManualExecutor executor = new ManualExecutor();
        executor.reject = true;
        MutableClock clock = clock();
        WeatherService service = service(uri -> FORECAST, clock, executor);
        try {
            assertSettledFailure(service.getCurrentWeatherIfReady(LAT, LNG));
            executor.reject = false;
            assertSettledFailure(service.getCurrentWeatherIfReady(LAT, LNG));
            assertThat(executor.submissions).isEqualTo(1);
            clock.advance(WeatherService.FAILURE_TTL_MS);
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
            assertThat(executor.submissions).isEqualTo(2);
            executor.runNext();
            assertThat(service.getCurrentWeatherIfReady(LAT, LNG)).containsEntry("available", true);
        } finally { service.shutdown(); }
    }

    @Test
    void ttlStartsAtCompletionNotEnqueueAndExpiredSuccessIsNotShownAsCurrent() {
        ManualExecutor executor = new ManualExecutor();
        MutableClock clock = clock();
        WeatherService service = service(uri -> FORECAST, clock, executor);
        try {
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
            clock.advance(20 * 60_000L);
            executor.runNext();
            clock.advance(WeatherService.SUCCESS_TTL_MS - 1);
            assertThat(service.getCurrentWeatherIfReady(LAT, LNG)).containsEntry("available", true);
            clock.advance(1);
            Map<String, Object> expired = service.getCurrentWeatherIfReady(LAT, LNG);
            assertPending(expired);
            assertThat(expired.get("temp")).isNull();
        } finally { service.shutdown(); }
    }

    @Test
    void newBaseAndDifferentGridNeverReuseOldCurrentWeather() {
        ManualExecutor executor = new ManualExecutor();
        MutableClock clock = clock();
        WeatherService service = service(uri -> FORECAST, clock, executor);
        try {
            service.getCurrentWeatherIfReady(LAT, LNG);
            executor.runNext();
            assertPending(service.getCurrentWeatherIfReady(35.1796, 129.0756));
            clock.advance(3 * 60 * 60_000L);
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
            assertThat(executor.tasks).hasSize(2);
        } finally { service.shutdown(); }
    }

    @Test
    void fallbackRetainsSourceMetadataAndKstEvenWithUtcInjectedClock() {
        ManualExecutor executor = new ManualExecutor();
        WeatherService service = new WeatherService("", uri -> { throw new AssertionError("No KMA key"); },
                uri -> "{\"current\":{\"time\":\"2026-10-06T14:45\",\"temperature_2m\":20.6,\"weather_code\":2}}",
                Clock.fixed(Instant.parse("2026-10-06T05:40:00Z"), ZoneOffset.UTC), executor);
        try {
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
            executor.runNext();
            assertThat(service.getCurrentWeatherIfReady(LAT, LNG)).containsEntry("available", true)
                    .containsEntry("source", "OPEN_METEO").containsEntry("fcstTime", "2026-10-06T14:45")
                    .containsEntry("updatedAt", "2026-10-06T05:40:00Z");
        } finally { service.shutdown(); }
    }

    @Test
    void invalidCoordinatesAndShutdownDoNotScheduleWork() {
        ManualExecutor executor = new ManualExecutor();
        WeatherService service = service(uri -> FORECAST, clock(), executor);
        assertSettledFailure(service.getCurrentWeatherIfReady(null, LNG));
        assertSettledFailure(service.getCurrentWeatherIfReady(Double.NaN, LNG));
        assertSettledFailure(service.getCurrentWeatherIfReady(0.0, 0.0));
        assertThat(executor.submissions).isZero();
        service.getCurrentWeatherIfReady(LAT, LNG);
        service.shutdown();
        assertThat(executor.isShutdown()).isTrue();
        assertThat(executor.tasks).isEmpty();
        assertSettledFailure(service.getCurrentWeatherIfReady(LAT, LNG));
    }

    @Test
    void staleForecastAndNonFiniteTemperatureNeverBecomeCurrent() {
        for (String invalid : List.of(FORECAST.replace("20261006", "20261005"),
                FORECAST.replace("\"21\"", "\"NaN\""), FORECAST.replace("\"21\"", "\"Infinity\""))) {
            ManualExecutor executor = new ManualExecutor();
            WeatherService service = service(uri -> invalid, clock(), executor);
            try {
                assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
                executor.runNext();
                assertSettledFailure(service.getCurrentWeatherIfReady(LAT, LNG));
                assertThat(service.getCurrentWeather(LAT, LNG).get("temp")).isNull();
            } finally { service.shutdown(); }
        }
    }

    @Test
    void invalidFallbackTimestampsAreNotAcceptedAsCurrent() {
        for (String timestamp : List.of("2026-10-05T14:45", "2026-10-06T16:00", "", "not-a-time")) {
            ManualExecutor executor = new ManualExecutor();
            WeatherService service = new WeatherService("", uri -> FORECAST,
                    uri -> "{\"current\":{\"time\":\"" + timestamp
                            + "\",\"temperature_2m\":21,\"weather_code\":0}}", clock(), executor);
            try {
                service.getCurrentWeatherIfReady(LAT, LNG);
                executor.runNext();
                assertSettledFailure(service.getCurrentWeatherIfReady(LAT, LNG));
            } finally { service.shutdown(); }
        }
    }

    @Test
    void sourceTimestampExpiryInvalidatesSuccessEvenBeforeCacheTtl() {
        ManualExecutor executor = new ManualExecutor();
        MutableClock clock = clock();
        WeatherService service = new WeatherService("", uri -> FORECAST,
                uri -> "{\"current\":{\"time\":\"2026-10-06T13:45\",\"temperature_2m\":21,\"weather_code\":0}}",
                clock, executor);
        try {
            service.getCurrentWeatherIfReady(LAT, LNG);
            executor.runNext();
            assertThat(service.getCurrentWeatherIfReady(LAT, LNG)).containsEntry("available", true);
            clock.advance(6 * 60_000L);
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
            executor.runNext();
            assertSettledFailure(service.getCurrentWeatherIfReady(LAT, LNG));
        } finally { service.shutdown(); }
    }

    @Test
    void simultaneousColdRequestsShareOneScheduledRefresh() throws Exception {
        ManualExecutor executor = new ManualExecutor();
        AtomicInteger providerCalls = new AtomicInteger();
        WeatherService service = service(uri -> { providerCalls.incrementAndGet(); return FORECAST; }, clock(), executor);
        ExecutorService callers = Executors.newFixedThreadPool(8);
        try {
            List<Callable<Map<String, Object>>> requests = new ArrayList<>();
            for (int i = 0; i < 64; i++) requests.add(() -> service.getCurrentWeatherIfReady(LAT, LNG));
            for (var response : callers.invokeAll(requests, 5, TimeUnit.SECONDS)) assertPending(response.get());
            assertThat(executor.tasks).hasSize(1);
            assertThat(providerCalls).hasValue(0);
            executor.runNext();
            assertThat(providerCalls).hasValue(1);
        } finally {
            callers.shutdownNow();
            service.shutdown();
        }
    }

    @Test
    void synchronousFailureCannotHideAnAlreadyAcceptedAsyncRefresh() {
        ManualExecutor executor = new ManualExecutor();
        WeatherService service = service(uri -> { throw new IllegalStateException("test failure"); }, clock(), executor);
        try {
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
            assertThat(service.getCurrentWeather(LAT, LNG)).containsEntry("available", false);
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
            executor.runNext();
            assertSettledFailure(service.getCurrentWeatherIfReady(LAT, LNG));
        } finally { service.shutdown(); }
    }

    @Test
    void lateFailedAsyncRefreshCannotReplaceFreshSynchronousSuccess() {
        ManualExecutor executor = new ManualExecutor();
        MutableClock clock = clock();
        AtomicInteger providerCalls = new AtomicInteger();
        WeatherService service = service(uri -> {
            if (providerCalls.incrementAndGet() == 1) return FORECAST;
            throw new IllegalStateException("late async failure");
        }, clock, executor);
        try {
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
            assertThat(service.getCurrentWeather(LAT, LNG)).containsEntry("available", true);
            clock.advance(20 * 60_000L);
            executor.runNext();
            assertThat(service.getCurrentWeatherIfReady(LAT, LNG)).containsEntry("available", true)
                    .containsEntry("refreshing", false).containsEntry("temp", 21);
            assertThat(providerCalls).hasValue(2);
            // Keeping a success must not renew its original TTL on each failure.
            clock.advance(10 * 60_000L);
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
        } finally { service.shutdown(); }
    }

    @Test
    void lateFailedSynchronousRouteCannotReplaceFreshAsyncSuccess() throws Exception {
        ManualExecutor executor = new ManualExecutor();
        AtomicInteger providerCalls = new AtomicInteger();
        CountDownLatch firstStarted = new CountDownLatch(1);
        CountDownLatch releaseFirst = new CountDownLatch(1);
        WeatherService service = service(uri -> {
            if (providerCalls.incrementAndGet() != 1) return FORECAST;
            firstStarted.countDown();
            try {
                if (!releaseFirst.await(5, TimeUnit.SECONDS)) throw new IllegalStateException("test wait expired");
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("test interrupted");
            }
            throw new IllegalStateException("late synchronous failure");
        }, clock(), executor);
        ExecutorService caller = Executors.newSingleThreadExecutor();
        try {
            var synchronous = caller.submit(() -> service.getCurrentWeather(LAT, LNG));
            assertThat(firstStarted.await(5, TimeUnit.SECONDS)).isTrue();
            assertPending(service.getCurrentWeatherIfReady(LAT, LNG));
            executor.runNext();
            assertThat(service.getCurrentWeatherIfReady(LAT, LNG)).containsEntry("available", true);
            releaseFirst.countDown();
            assertThat(synchronous.get(5, TimeUnit.SECONDS)).containsEntry("available", false);
            assertThat(service.getCurrentWeatherIfReady(LAT, LNG)).containsEntry("available", true)
                    .containsEntry("refreshing", false).containsEntry("temp", 21);
            assertThat(providerCalls).hasValue(2);
        } finally {
            releaseFirst.countDown();
            caller.shutdownNow();
            service.shutdown();
        }
    }

    @Test
    void defaultExecutorHasFewDaemonThreadsABoundedQueueAndLifecycleShutdown() throws Exception {
        WeatherService service = new WeatherService("test-key", uri -> FORECAST, clock());
        try {
            var field = WeatherService.class.getDeclaredField("refreshExecutor");
            field.setAccessible(true);
            ThreadPoolExecutor executor = (ThreadPoolExecutor) field.get(service);
            assertThat(executor.getCorePoolSize()).isEqualTo(2);
            assertThat(executor.getMaximumPoolSize()).isEqualTo(2);
            assertThat(executor.getQueue().remainingCapacity()).isEqualTo(32);
            Thread worker = executor.getThreadFactory().newThread(() -> {});
            assertThat(worker.isDaemon()).isTrue();
            assertThat(worker.getName()).startsWith("weather-refresh-");
            service.shutdown();
            assertThat(executor.isShutdown()).isTrue();
        } finally { service.shutdown(); }
    }

    @Test
    void completedCacheRemainsBoundedAcrossManyDifferentGrids() throws Exception {
        ManualExecutor executor = new ManualExecutor();
        AtomicInteger providerCalls = new AtomicInteger();
        WeatherService service = service(uri -> { providerCalls.incrementAndGet(); return FORECAST; }, clock(), executor);
        try {
            for (int i = 0; i < 800; i++) {
                service.getCurrentWeather(34.0 + (i / 40) * 0.10, 126.0 + (i % 40) * 0.10);
            }
            assertThat(providerCalls.get()).isGreaterThan(512);
            var field = WeatherService.class.getDeclaredField("cache");
            field.setAccessible(true);
            assertThat(((Map<?, ?>) field.get(service)).size()).isBetween(1, 512);
        } finally { service.shutdown(); }
    }

    private static WeatherService service(Function<URI, String> fetcher, Clock clock, ManualExecutor executor) {
        return new WeatherService("test-key", fetcher, null, clock, executor);
    }

    private static void assertPending(Map<String, Object> result) {
        assertThat(result).containsEntry("available", false).containsEntry("refreshing", true)
                .containsEntry("weather", "알 수 없음");
        assertThat(result.get("temp")).isNull();
    }

    private static void assertSettledFailure(Map<String, Object> result) {
        assertThat(result).containsEntry("available", false).containsEntry("refreshing", false);
    }

    private static MutableClock clock() { return new MutableClock(Instant.parse("2026-10-06T05:40:00Z")); }

    private static final class MutableClock extends Clock {
        private Instant now;
        MutableClock(Instant now) { this.now = now; }
        void advance(long millis) { now = now.plusMillis(millis); }
        @Override public ZoneId getZone() { return ZoneId.of("Asia/Seoul"); }
        @Override public Clock withZone(ZoneId zone) { return this; }
        @Override public Instant instant() { return now; }
    }

    private static final class ManualExecutor extends AbstractExecutorService {
        private final Queue<Runnable> tasks = new ArrayDeque<>();
        private boolean stopped;
        private boolean reject;
        private int submissions;
        void runNext() { tasks.remove().run(); }
        @Override public void execute(Runnable command) {
            submissions++;
            if (reject || stopped) throw new RejectedExecutionException("controlled rejection");
            tasks.add(command);
        }
        @Override public void shutdown() { stopped = true; }
        @Override public List<Runnable> shutdownNow() {
            stopped = true;
            List<Runnable> abandoned = new ArrayList<>(tasks);
            tasks.clear();
            return abandoned;
        }
        @Override public boolean isShutdown() { return stopped; }
        @Override public boolean isTerminated() { return stopped && tasks.isEmpty(); }
        @Override public boolean awaitTermination(long timeout, TimeUnit unit) { return isTerminated(); }
    }
}
