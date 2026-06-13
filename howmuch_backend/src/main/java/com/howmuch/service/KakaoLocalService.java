package com.howmuch.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.util.Map;

@Slf4j
@Service
public class KakaoLocalService {

    // 💡 카카오 개발자 센터의 REST API 키를 사용합니다.
    private final String KAKAO_REST_API_KEY = "224e0cadbd6a8505be5becb3cac3fcaa"; 
    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public Map<String, Object> getCoordinatesFromAddress(String address) {
        try {
            String url = "https://dapi.kakao.com/v2/local/search/address.json";
            
            URI uri = UriComponentsBuilder.fromHttpUrl(url)
                    .queryParam("query", address)
                    .build()
                    .encode()
                    .toUri();

            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "KakaoAK " + KAKAO_REST_API_KEY);

            HttpEntity<String> entity = new HttpEntity<>(headers);
            ResponseEntity<String> response = restTemplate.exchange(uri, HttpMethod.GET, entity, String.class);

            JsonNode root = objectMapper.readTree(response.getBody());
            JsonNode documents = root.path("documents");

            if (documents.isArray() && documents.size() > 0) {
                JsonNode firstDoc = documents.get(0);
                JsonNode addrNode = firstDoc.path("address");

                double lon = firstDoc.path("x").asDouble(); 
                double lat = firstDoc.path("y").asDouble();
                String province = addrNode.path("region_1depth_name").asText(); // 예: 서울
                String district = addrNode.path("region_2depth_name").asText(); // 예: 마포구

                return Map.of(
                    "lat", lat, 
                    "lng", lon,
                    "province", province,
                    "district", district
                );
            }
        } catch (Exception e) {
            log.error("주소 변환 중 오류 발생 (주소: {}): ", address, e);
        }
        return null;
    }
}
