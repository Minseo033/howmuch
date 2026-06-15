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
    private final String KAKAO_REST_API_KEY = "a262460cc196a9dd283003c7d54743b3"; 
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
            // 💡 최신 카카오 로컬 API 정책에 의해 KA 헤더 및 Origin 헤더가 필수적으로 요구될 수 있습니다.
            headers.set("KA", "sdk/1.0 os/javascript origin/http://localhost:8081");
            headers.set("Origin", "http://localhost:8081");

            HttpEntity<String> entity = new HttpEntity<>(headers);
            ResponseEntity<String> response = restTemplate.exchange(uri, HttpMethod.GET, entity, String.class);

            JsonNode root = objectMapper.readTree(response.getBody());
            JsonNode documents = root.path("documents");

            if (documents.isArray() && documents.size() > 0) {
                JsonNode firstDoc = documents.get(0);
                JsonNode addrNode = firstDoc.path("address");

                double lon = firstDoc.path("x").asDouble(); 
                double lat = firstDoc.path("y").asDouble();
                
                String province = "";
                String district = "";
                
                if (!addrNode.isMissingNode() && !addrNode.isNull()) {
                    province = addrNode.path("region_1depth_name").asText("");
                    district = addrNode.path("region_2depth_name").asText("");
                } else {
                    JsonNode roadAddrNode = firstDoc.path("road_address");
                    if (!roadAddrNode.isMissingNode() && !roadAddrNode.isNull()) {
                        province = roadAddrNode.path("region_1depth_name").asText("");
                        district = roadAddrNode.path("region_2depth_name").asText("");
                    }
                }

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
