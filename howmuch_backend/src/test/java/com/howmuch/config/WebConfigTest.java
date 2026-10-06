package com.howmuch.config;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class WebConfigTest {

    private static final String WEB_ORIGIN = "https://howmuch-zeta.vercel.app";

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

    @Test
    void preflightResultIsCachedByTheBrowserForAnHour() throws Exception {
        MockHttpServletRequest preflight = new MockHttpServletRequest("OPTIONS", "/api/notifications");
        preflight.addHeader("Origin", WEB_ORIGIN);
        preflight.addHeader("Access-Control-Request-Method", "GET");
        preflight.addHeader("Access-Control-Request-Headers", "authorization");
        MockHttpServletResponse response = new MockHttpServletResponse();

        new WebConfig(WEB_ORIGIN).corsFilterRegistration().getFilter()
                .doFilter(preflight, response, new MockFilterChain());

        assertThat(response.getHeader("Access-Control-Allow-Origin")).isEqualTo(WEB_ORIGIN);
        assertThat(response.getHeader("Access-Control-Max-Age")).isEqualTo("3600");
    }

    @Test
    void webClientCanReadTheTruncatedMapHeader() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/stores/bounds");
        request.addHeader("Origin", WEB_ORIGIN);
        MockHttpServletResponse response = new MockHttpServletResponse();

        new WebConfig(WEB_ORIGIN).corsFilterRegistration().getFilter()
                .doFilter(request, response, new MockFilterChain());

        assertThat(response.getHeader("Access-Control-Expose-Headers"))
                .contains("X-Stores-Truncated", "Retry-After");
    }
}
