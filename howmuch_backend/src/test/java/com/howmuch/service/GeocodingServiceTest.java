package com.howmuch.service;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.reactive.function.client.ClientResponse;
import org.springframework.web.reactive.function.client.WebClient;

import java.time.Duration;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class GeocodingServiceTest {

    @Test
    void parsesOnlyFiniteCoordinatesInRange() {
        WebClient client = clientReturning("""
                {"documents":[{"x":"126.9780","y":"37.5665"}]}
                """);
        GeocodingService service = new GeocodingService(
                client, "test-key", Duration.ofSeconds(1));

        Map<String, Double> result = service.getCoordinates(" 서울시 중구 ").block();

        assertThat(result)
                .containsEntry("latitude", 37.5665)
                .containsEntry("longitude", 126.9780);
    }

    @Test
    void missingOrOutOfRangeCoordinatesProduceNoResult() {
        GeocodingService missing = new GeocodingService(
                clientReturning("{\"documents\":[{}]}"),
                "test-key", Duration.ofSeconds(1));
        GeocodingService invalid = new GeocodingService(
                clientReturning("{\"documents\":[{\"x\":\"0\",\"y\":\"999\"}]}"),
                "test-key", Duration.ofSeconds(1));

        assertThat(missing.getCoordinates("주소").blockOptional()).isEmpty();
        assertThat(invalid.getCoordinates("주소").blockOptional()).isEmpty();
    }

    @Test
    void missingKeyAndInvalidAddressDoNotCallTheNetwork() {
        WebClient exploding = WebClient.builder()
                .exchangeFunction(request -> {
                    throw new AssertionError("network must not be called");
                })
                .build();

        assertThat(new GeocodingService(exploding, "", Duration.ofSeconds(1))
                .getCoordinates("서울").blockOptional()).isEmpty();
        assertThat(new GeocodingService(exploding, "key", Duration.ofSeconds(1))
                .getCoordinates("가".repeat(301)).blockOptional()).isEmpty();
    }

    private WebClient clientReturning(String body) {
        return WebClient.builder()
                .baseUrl("https://dapi.kakao.com")
                .exchangeFunction(request -> reactor.core.publisher.Mono.just(
                        ClientResponse.create(HttpStatus.OK)
                                .header("Content-Type", MediaType.APPLICATION_JSON_VALUE)
                                .body(body)
                                .build()))
                .build();
    }
}
