package com.howmuch.service;

import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class WeatherServiceTest {

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
