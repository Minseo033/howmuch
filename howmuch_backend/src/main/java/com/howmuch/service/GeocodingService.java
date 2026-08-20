package com.howmuch.service;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.util.Map;

@Service
public class GeocodingService {

    private final WebClient webClient;
    // 💡 카카오 REST API 키는 환경변수(KAKAO_REST_API_KEY)로만 주입합니다 (레포 public — 하드코딩 금지)
    private final String kakaoApiKey;
    private final Duration timeout;

    public GeocodingService(WebClient.Builder webClientBuilder,
                            @Value("${kakao.rest-api-key:}") String kakaoApiKey,
                            @Value("${kakao.local.timeout-ms:5000}") long timeoutMillis) {
        this(webClientBuilder.baseUrl("https://dapi.kakao.com").build(),
                kakaoApiKey,
                Duration.ofMillis(Math.max(1_000L, timeoutMillis)));
    }

    GeocodingService(WebClient webClient, String kakaoApiKey, Duration timeout) {
        this.webClient = webClient;
        this.kakaoApiKey = kakaoApiKey;
        this.timeout = timeout;
    }

    /**
     * 주소를 기반으로 위도와 경도를 추출합니다.
     */
    public Mono<Map<String, Double>> getCoordinates(String address) {
        if (address == null || address.isBlank() || address.trim().length() > 300) {
            return Mono.empty();
        }

        if (kakaoApiKey == null || kakaoApiKey.isBlank()) {
            // 키 미설정 시 외부 API 호출 없이 실패 안전하게 빈 결과 반환
            return Mono.empty();
        }

        return webClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/v2/local/search/address.json")
                        .queryParam("query", address.trim())
                        .build())
                .header("Authorization", "KakaoAK " + kakaoApiKey)
                .retrieve()
                .bodyToMono(JsonNode.class)
                .flatMap(jsonNode -> {
                    JsonNode documents = jsonNode.path("documents");
                    if (documents.isArray() && !documents.isEmpty()) {
                        JsonNode firstDoc = documents.get(0);
                        double x = firstDoc.path("x").asDouble(Double.NaN); // longitude
                        double y = firstDoc.path("y").asDouble(Double.NaN); // latitude
                        if (Double.isFinite(x) && Double.isFinite(y)
                                && y >= -90 && y <= 90 && x >= -180 && x <= 180) {
                            return Mono.just(Map.of("latitude", y, "longitude", x));
                        }
                    }
                    return Mono.empty();
                })
                .timeout(timeout)
                .onErrorResume(ignored -> Mono.empty());
    }
}
