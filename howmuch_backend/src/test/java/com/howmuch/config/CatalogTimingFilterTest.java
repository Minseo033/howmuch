package com.howmuch.config;

import com.google.cloud.firestore.Firestore;
import com.howmuch.controller.StoresController;
import com.howmuch.diagnostics.CatalogTiming;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.ReportImageStorage;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Executors;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(OutputCaptureExtension.class)
class CatalogTimingFilterTest {
    private final CatalogTimingFilter filter = new CatalogTimingFilter();

    @Test
    void streamsImmediatelyWithHeadersBeforeCommitWithoutCopyingTheBody(CapturedOutput output) throws Exception {
        var request = new MockHttpServletRequest("GET", "/api/stores/catalog");
        request.setQueryString("secret=private-query");
        request.addHeader("Authorization", "Bearer private-token");
        request.addHeader("X-Catalog-Request-Id", "private-client-id");
        var response = new MockHttpServletResponse();
        byte[] body = "{\"매장\":\"분식\"}".getBytes(StandardCharsets.UTF_8);

        filter.doFilter(request, response, (req, res) -> {
            CatalogTiming.record("catalog_build", System.nanoTime());
            CatalogTiming.source("miss", 11391, false);
            res.setContentType("application/json");
            res.getOutputStream().write(body);
            assertThat(response.getContentAsByteArray()).isEqualTo(body);
            assertThat(response.getHeader("Server-Timing")).contains("catalog_build;dur=", "app_prewrite;dur=");
            res.flushBuffer();
            assertThat(response.isCommitted()).isTrue();
        });

        assertThat(response.getContentAsByteArray()).isEqualTo(body);
        assertThat(UUID.fromString(response.getHeader("X-Catalog-Request-Id"))).isNotNull();
        assertThat(output).contains("source_cache=miss", "stores=11391", "output_bytes=" + body.length)
                .doesNotContain("private-query", "private-token", "private-client-id", "분식");
        assertThat(((ThreadLocal<?>) ReflectionTestUtils.getField(CatalogTiming.class, "CURRENT")).get()).isNull();
    }

    @Test
    void bodylessValidationAndFailuresGetHeadersAndDoNotLeakToTheNextRequest() throws Exception {
        for (int status : new int[]{304, 503}) {
            var response = new MockHttpServletResponse();
            filter.doFilter(new MockHttpServletRequest("GET", "/api/stores/all"), response,
                    (req, res) -> ((HttpServletResponse) res).setStatus(status));
            assertThat(response.getStatus()).isEqualTo(status);
            assertThat(response.getHeader("Server-Timing")).startsWith("app_prewrite;dur=");
            assertThat(response.getContentAsByteArray()).isEmpty();
        }
        assertThatThrownBy(() -> filter.doFilter(new MockHttpServletRequest("GET", "/api/stores/catalog"),
                new MockHttpServletResponse(), (req, res) -> {
                    CatalogTiming.record("catalog_build", System.nanoTime());
                    throw new IOException("connection closed");
                })).isInstanceOf(IOException.class);
        assertThat(((ThreadLocal<?>) ReflectionTestUtils.getField(CatalogTiming.class, "CURRENT")).get()).isNull();
        // A pooled servlet thread must not carry measurements into its next request.
        CatalogTiming.record("should_not_leak", System.nanoTime());
        var next = new MockHttpServletResponse();
        filter.doFilter(new MockHttpServletRequest("GET", "/api/stores/catalog"), next, (req, res) -> {});
        assertThat(next.getHeader("Server-Timing")).startsWith("app_prewrite;dur=")
                .doesNotContain("catalog_build", "should_not_leak");
    }

    @Test
    void unrelatedRoutesAndPreflightsRemainUnwrapped() throws Exception {
        for (var request : List.of(new MockHttpServletRequest("GET", "/api/user/profile"),
                new MockHttpServletRequest("POST", "/api/stores/catalog"),
                new MockHttpServletRequest("OPTIONS", "/api/stores/catalog"))) {
            var response = new MockHttpServletResponse();
            filter.doFilter(request, response, (req, res) -> assertThat(res).isSameAs(response));
            assertThat(response.getHeader("Server-Timing")).isNull();
        }
    }

    @Test
    void characterResponsesKeepContainerEncodingAndWriterStreamExclusion() throws Exception {
        var response = new MockHttpServletResponse();
        filter.doFilter(new MockHttpServletRequest("GET", "/api/stores/catalog"), response, (req, res) -> {
            res.setCharacterEncoding("UTF-8");
            res.getWriter().write("한글 응답");
            assertThatThrownBy(res::getOutputStream).isInstanceOf(IllegalStateException.class);
            res.flushBuffer();
        });
        assertThat(response.getContentAsString(StandardCharsets.UTF_8)).isEqualTo("한글 응답");
        assertThat(response.getHeader("Server-Timing")).contains("app_prewrite");
    }

    @Test
    void coldAndWarmHttpResponsesKeepPayloadAndEtagWhileReportingDistinctPhases() throws Exception {
        var service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(service, "cachedStores", List.of(Map.of(
                "storeId", "gov-test", "storeName", "분식", "latitude", 37.5, "longitude", 127.0,
                "openingHours", Map.of("text", "09:00~18:00"))));
        var mvc = MockMvcBuilders.standaloneSetup(new StoresController(service)).addFilters(filter).build();
        var cold = mvc.perform(get("/api/stores/catalog")).andExpect(status().isOk()).andReturn().getResponse();
        assertThat(cold.getHeader("Server-Timing")).contains("catalog_wait;dur=", "catalog_build;dur=",
                "catalog_etag;dur=", "map_wait;dur=", "map_build;dur=", "app_prewrite;dur=");
        assertThat(cold.getContentAsString(StandardCharsets.UTF_8)).contains("분식")
                .doesNotContain("openingHours");
        var warm = mvc.perform(get("/api/stores/catalog")).andExpect(status().isOk()).andReturn().getResponse();
        assertThat(warm.getContentAsByteArray()).isEqualTo(cold.getContentAsByteArray());
        assertThat(warm.getHeader("ETag")).isEqualTo(cold.getHeader("ETag"));
        assertThat(warm.getHeader("Server-Timing")).doesNotContain("catalog_build", "catalog_etag", "map_build");
        assertThat(warm.getHeader("X-Catalog-Request-Id")).isNotEqualTo(cold.getHeader("X-Catalog-Request-Id"));
        var unchanged = mvc.perform(get("/api/stores/catalog").header("If-None-Match", cold.getHeader("ETag")))
                .andExpect(status().isNotModified()).andReturn().getResponse();
        assertThat(unchanged.getHeader("Server-Timing")).contains("app_prewrite;dur=");
        assertThat(unchanged.getContentAsByteArray()).isEmpty();
    }

    @Test
    void concurrentRequestsHaveIndependentMeasurements() throws Exception {
        try (var pool = Executors.newFixedThreadPool(2)) {
            var first = pool.submit(() -> {
                var response = new MockHttpServletResponse();
                filter.doFilter(new MockHttpServletRequest("GET", "/api/stores/catalog"), response,
                        (req, res) -> CatalogTiming.record("first_only", System.nanoTime()));
                return response;
            });
            var second = pool.submit(() -> {
                var response = new MockHttpServletResponse();
                filter.doFilter(new MockHttpServletRequest("GET", "/api/stores/catalog"), response,
                        (req, res) -> CatalogTiming.record("second_only", System.nanoTime()));
                return response;
            });
            assertThat(first.get().getHeader("Server-Timing")).contains("first_only").doesNotContain("second_only");
            assertThat(second.get().getHeader("Server-Timing")).contains("second_only").doesNotContain("first_only");
        }
    }
}
