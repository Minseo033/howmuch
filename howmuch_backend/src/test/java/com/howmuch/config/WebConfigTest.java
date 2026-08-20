package com.howmuch.config;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class WebConfigTest {

    @Test
    void parsesAndDeduplicatesConfiguredCorsOrigins() {
        assertThat(WebConfig.parseOriginPatterns(
                " https://howmuch-zeta.vercel.app, http://localhost:*,https://howmuch-zeta.vercel.app "))
                .containsExactly("https://howmuch-zeta.vercel.app", "http://localhost:*");
    }

    @Test
    void refusesAnEmptyCorsConfiguration() {
        assertThatThrownBy(() -> WebConfig.parseOriginPatterns(" , "))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
