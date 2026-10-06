package com.howmuch.config;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.List;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    private static final List<String> ALLOWED_METHODS = List.of("GET", "POST", "PUT", "DELETE", "OPTIONS");
    /** 브라우저는 노출 목록에 없는 응답 헤더를 스크립트에서 숨긴다(지도 범위 잘림 표시, 재시도 안내). */
    static final List<String> EXPOSED_HEADERS = List.of("X-Stores-Truncated", "Retry-After");
    /** 인증 요청마다 사전 요청(OPTIONS)이 반복되지 않도록 결과를 1시간 재사용하게 한다. */
    static final long PREFLIGHT_MAX_AGE_SECONDS = 3600L;

    private final List<String> allowedOriginPatterns;

    public WebConfig(@Value("${cors.allowed-origin-patterns}") String allowedOriginPatterns) {
        this.allowedOriginPatterns = parseOriginPatterns(allowedOriginPatterns);
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOriginPatterns(allowedOriginPatterns.toArray(String[]::new))
                .allowedMethods(ALLOWED_METHODS.toArray(String[]::new))
                .allowedHeaders("*")
                .exposedHeaders(EXPOSED_HEADERS.toArray(String[]::new))
                .maxAge(PREFLIGHT_MAX_AGE_SECONDS);
    }

    /**
     * CORS 처리를 서블릿 필터 최상위(HIGHEST_PRECEDENCE)에서 수행.
     * addCorsMappings는 DispatcherServlet 레벨이라 SessionAuthFilter가 직접 반환하는
     * 401 응답에는 Access-Control-Allow-Origin이 붙지 않아 브라우저가 401을 CORS 에러로
     * 오인하는 문제가 있었음 (웹 QA에서 인증 API 전부 CORS 실패로 표시).
     * 이 필터는 SessionAuthFilter보다 먼저 실행되어 401 포함 모든 응답에 CORS 헤더를 보장합니다.
     */
    @Bean
    public FilterRegistrationBean<CorsFilter> corsFilterRegistration() {
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", corsConfiguration());

        FilterRegistrationBean<CorsFilter> bean = new FilterRegistrationBean<>(new CorsFilter(source));
        bean.setOrder(Ordered.HIGHEST_PRECEDENCE);
        return bean;
    }

    CorsConfiguration corsConfiguration() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(allowedOriginPatterns);
        config.setAllowedMethods(ALLOWED_METHODS);
        config.setAllowedHeaders(List.of("*"));
        config.setExposedHeaders(EXPOSED_HEADERS);
        config.setMaxAge(PREFLIGHT_MAX_AGE_SECONDS);
        return config;
    }

    static List<String> parseOriginPatterns(String rawPatterns) {
        List<String> patterns = java.util.Arrays.stream(rawPatterns.split(","))
                .map(String::trim)
                .filter(pattern -> !pattern.isBlank())
                .distinct()
                .toList();
        if (patterns.isEmpty()) {
            throw new IllegalArgumentException("CORS 허용 출처가 하나 이상 필요합니다.");
        }
        return patterns;
    }
}
