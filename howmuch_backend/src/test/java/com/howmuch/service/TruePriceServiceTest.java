package com.howmuch.service;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class TruePriceServiceTest {

    @Test
    void parsesOfficialRegionalPriceTableAndBasisMonth() {
        String html = """
                <select id='searchYear'><option value='2026' selected>2026</option></select>
                <select id='searchMonth'><option value='07' selected>07</option></select>
                <table><caption>지역별 외식비 정보</caption><tbody>
                <tr><td>서울</td><td>12,000</td><td>11,000</td></tr>
                </tbody></table>
                """;
        TruePriceService service = new TruePriceService(1_000);

        TruePriceService.ParsedTable parsed = service.parseTable(
                html, "지역별 외식비 정보", List.of("냉면", "비빔밥"));

        assertThat(parsed.basisDate()).isEqualTo("2026-07");
        assertThat(parsed.values().get("서울").get("냉면")).isEqualTo(12_000L);
    }

    @Test
    void matchesOnlyComparableOfficialItems() {
        assertThat(TruePriceService.matchOfficialItem("짜장면", "중식")).isEqualTo("자장면");
        assertThat(TruePriceService.matchOfficialItem("여성 커트", "미용업")).isEqualTo("미용");
        assertThat(TruePriceService.matchOfficialItem("제육볶음", "한식")).isNull();
    }

    @Test
    void resolvesProvinceFromStoreAddress() {
        assertThat(TruePriceService.resolveRegion("경기도 수원시 팔달구")).isEqualTo("경기");
        assertThat(TruePriceService.resolveRegion("제주특별자치도 제주시")).isEqualTo("제주");
    }

    @Test
    void servesBundledOfficialPricesBeforeTheBackgroundRefresh() {
        TruePriceService service = new TruePriceService(1_000);

        ReferencePrices.Estimate estimate = service
                .estimate("김치찌개", "한식", "경기도 수원시")
                .orElseThrow();

        assertThat(estimate.referencePrice()).isEqualTo(8_841L);
        assertThat(estimate.source()).isEqualTo("TRUE_PRICE");
        assertThat(estimate.basisDate()).isEqualTo("2026-07");
    }
}
