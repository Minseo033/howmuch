package com.howmuch.service;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class GeminiServiceTest {

    @Test
    void localRouteDoesNotDuplicateTheWonSuffix() {
        GeminiService service = new GeminiService("", 1_000, false);

        String route = service.getRouteRecommendation(List.of(
                Map.of(
                        "storeName", "실제 매장",
                        "menu1", "아메리카노",
                        "price1", "2,000원",
                        "distanceMeters", 120),
                Map.of(
                        "storeName", "다른 매장",
                        "menu1", "국수",
                        "price1", "5000",
                        "distanceMeters", 300)));

        assertThat(route).contains("2,000원", "5000원");
        assertThat(route).doesNotContain("원원");
    }
}
