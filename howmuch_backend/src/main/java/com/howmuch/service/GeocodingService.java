package com.howmuch.service;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.Map;

@Service
public class GeocodingService {

    private final WebClient webClient;
    private final String KAKAO_API_KEY = "a262460cc196a9dd283003c7d54743b3";

    public GeocodingService(WebClient.Builder webClientBuilder) {
        this.webClient = webClientBuilder.baseUrl("https://dapi.kakao.com").build();
    }

    /**
     * 주소를 기반으로 위도와 경도를 추출합니다.
     */
    public Mono<Map<String, Double>> getCoordinates(String address) {
        if (address == null || address.isBlank()) {
            return Mono.empty();
        }

        return webClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/v2/local/search/address.json")
                        .queryParam("query", address)
                        .build())
                .header("Authorization", "KakaoAK " + KAKAO_API_KEY)
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
