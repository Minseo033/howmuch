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

    private final List<String> allowedOriginPatterns;

    public WebConfig(@Value("${cors.allowed-origin-patterns}") String allowedOriginPatterns) {
        this.allowedOriginPatterns = parseOriginPatterns(allowedOriginPatterns);
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOriginPatterns(allowedOriginPatterns.toArray(String[]::new))
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*");
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
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(allowedOriginPatterns);
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);

        FilterRegistrationBean<CorsFilter> bean = new FilterRegistrationBean<>(new CorsFilter(source));
        bean.setOrder(Ordered.HIGHEST_PRECEDENCE);
        return bean;
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
