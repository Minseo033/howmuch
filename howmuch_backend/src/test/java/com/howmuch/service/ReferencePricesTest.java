package com.howmuch.service;

import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class ReferencePricesTest {

    @Test
    void usesMedianOfActualMatchingMenuPrices() {
        List<Map<String, Object>> stores = List.of(
                Map.of("menu1", "김치찌개", "price1", "7,000원", "industry", "한식"),
                Map.of("menu1", "김치찌개", "price1", "9000", "industry", "한식"),
                Map.of("menu1", "김치찌개 백반", "price1", "8000", "industry", "한식"));

        ReferencePrices.Estimate estimate = ReferencePrices
                .estimateFromPublicStores(stores, "김치찌개", "한식")
                .orElseThrow();

        assertThat(estimate.referencePrice()).isEqualTo(8_000L);
        assertThat(estimate.source()).isEqualTo("PUBLIC_STORE_MENU");
        assertThat(estimate.sampleSize()).isEqualTo(2);
    }

    @Test
    void fallsBackToIndustryMedianWithoutInventingAPrice() {
        List<Map<String, Object>> stores = List.of(
                Map.of("menu1", "백반", "price1", "6000", "industry", "한식"),
                Map.of("menu1", "국밥", "price1", "8000", "industry", "한식"));

        ReferencePrices.Estimate estimate = ReferencePrices
                .estimateFromPublicStores(stores, "없는 메뉴", "한식")
                .orElseThrow();

        assertThat(estimate.referencePrice()).isEqualTo(7_000L);
        assertThat(estimate.source()).isEqualTo("PUBLIC_STORE_INDUSTRY");
    }

    @Test
    void returnsEmptyWhenNoRealPriceSampleExists() {
        assertThat(ReferencePrices.estimateFromPublicStores(
                List.of(Map.of("menu1", "메뉴", "price1", "정보 없음", "industry", "한식")),
                "메뉴", "한식")).isEmpty();
    }
}
