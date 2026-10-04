package com.howmuch.service;

import org.junit.jupiter.api.Test;
import java.util.List;
import static org.assertj.core.api.Assertions.assertThat;

class WonPriceTest {
    @Test void keepsAlternativesAndRangesSeparate() {
        var alternatives = WonPrice.parse("3,000 / 3,500").orElseThrow();
        assertThat(alternatives.amounts()).isEqualTo(List.of(3000L, 3500L));
        assertThat(alternatives.exact()).isFalse();
        assertThat(WonPrice.parse("3000~3500원").orElseThrow().range()).isTrue();
        assertThat(WonPrice.exactPositive("3,000 / 3,500")).isNull();
    }
    @Test void rejectsMalformedAndNegativePrices() {
        for (Object input : List.of("", "-1000", "3,00", "3000/", "3500~3000", "10,000,001", "3000명 3500원", 3000.5, Double.NaN)) {
            assertThat(WonPrice.parse(input)).as("%s", input).isEmpty();
        }
        assertThat(WonPrice.parse(3000.0).orElseThrow().minimum()).isEqualTo(3000L);
    }
    @Test void zeroNeedsExplicitFreeAndCannotBeAMixedRange() {
        assertThat(WonPrice.menuMinimum("0", false)).isNull();
        assertThat(WonPrice.menuMinimum("0", true)).isZero();
        assertThat(WonPrice.menuMinimum("0 / 3000", true)).isNull();
        assertThat(WonPrice.menuMinimum("3000", true)).isNull();
    }
}
