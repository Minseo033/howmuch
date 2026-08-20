package com.howmuch.service;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.client.ExpectedCount.once;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.headerDoesNotExist;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.queryParam;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

class KakaoLocalServiceTest {

    @Test
    void usesOnlyTheDocumentedAuthorizationHeaderAndParsesCoordinates() {
        RestTemplate restTemplate = new RestTemplate();
        MockRestServiceServer server = MockRestServiceServer.bindTo(restTemplate).build();
        server.expect(once(), queryParam("query", "%EC%84%9C%EC%9A%B8%EC%8B%9C%20%EC%A4%91%EA%B5%AC%20%EC%84%B8%EC%A2%85%EB%8C%80%EB%A1%9C%20110"))
                .andExpect(header(HttpHeaders.AUTHORIZATION, "KakaoAK test-key"))
                .andExpect(headerDoesNotExist(HttpHeaders.ORIGIN))
                .andExpect(headerDoesNotExist("KA"))
                .andRespond(withSuccess("""
                        {"documents":[{"x":"126.9780","y":"37.5665","address":{
                          "region_1depth_name":"서울","region_2depth_name":"중구"}}]}
                        """, MediaType.APPLICATION_JSON));
        KakaoLocalService service = new KakaoLocalService("test-key", restTemplate);

        Map<String, Object> coordinates = service.getCoordinatesFromAddress(
                "  서울시 중구 세종대로 110  ");

        assertThat(coordinates)
                .containsEntry("lat", 37.5665)
                .containsEntry("lng", 126.9780)
                .containsEntry("district", "중구");
        server.verify();
    }

    @Test
    void rejectsBlankAndOversizedAddressesWithoutCallingKakao() {
        RestTemplate restTemplate = new RestTemplate();
        MockRestServiceServer server = MockRestServiceServer.bindTo(restTemplate).build();
        KakaoLocalService service = new KakaoLocalService("test-key", restTemplate);

        assertThat(service.getCoordinatesFromAddress("   ")).isNull();
        assertThat(service.getCoordinatesFromAddress("가".repeat(301))).isNull();
        server.verify();
    }

    @Test
    void rejectsMissingCoordinatesInsteadOfReturningZeroZero() {
        RestTemplate restTemplate = new RestTemplate();
        MockRestServiceServer server = MockRestServiceServer.bindTo(restTemplate).build();
        server.expect(once(), queryParam("query", "%EC%A2%8C%ED%91%9C%20%EC%97%86%EB%8A%94%20%EC%A3%BC%EC%86%8C"))
                .andRespond(withSuccess("{\"documents\":[{}]}", MediaType.APPLICATION_JSON));
        KakaoLocalService service = new KakaoLocalService("test-key", restTemplate);

        assertThat(service.getCoordinatesFromAddress("좌표 없는 주소")).isNull();
        server.verify();
    }
}
