package com.howmuch.service;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.Map;

@Service
public class GeocodingService {

    private final WebClient webClient;
    // 💡 카카오 REST API 키는 환경변수(KAKAO_REST_API_KEY)로만 주입합니다 (레포 public — 하드코딩 금지)
    private final String kakaoApiKey;

    public GeocodingService(WebClient.Builder webClientBuilder,
                            @Value("${kakao.rest-api-key:}") String kakaoApiKey) {
        this.webClient = webClientBuilder.baseUrl("https://dapi.kakao.com").build();
        this.kakaoApiKey = kakaoApiKey;
    }

    /**
     * 주소를 기반으로 위도와 경도를 추출합니다.
     */
    public Mono<Map<String, Double>> getCoordinates(String address) {
        if (address == null || address.isBlank()) {
            return Mono.empty();
        }

        if (kakaoApiKey == null || kakaoApiKey.isBlank()) {
            // 키 미설정 시 외부 API 호출 없이 실패 안전하게 빈 결과 반환
            return Mono.empty();
        }

        return webClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/v2/local/search/address.json")
                        .queryParam("query", address)
                        .build())
                .header("Authorization", "KakaoAK " + kakaoApiKey)
                .retrieve()
                .bodyToMono(JsonNode.class)
                .map(jsonNode -> {
                    JsonNode documents = jsonNode.path("documents");
                    if (documents.isArray() && !documents.isEmpty()) {
                        JsonNode firstDoc = documents.get(0);
                        double x = firstDoc.path("x").asDouble(); // longitude
                        double y = firstDoc.path("y").asDouble(); // latitude
                        return Map.of("latitude", y, "longitude", x);
                    }
                    return Map.of("latitude", 0.0, "longitude", 0.0);
                })
                .onErrorReturn(Map.of("latitude", 0.0, "longitude", 0.0));
    }
}
