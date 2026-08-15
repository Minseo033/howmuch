package com.howmuch.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
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

    // 💡 카카오 REST API 키는 환경변수(KAKAO_REST_API_KEY)로만 주입합니다 (레포 public — 하드코딩 금지)
    private final String kakaoRestApiKey;
    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public KakaoLocalService(@Value("${kakao.rest-api-key:}") String kakaoRestApiKey) {
        this.kakaoRestApiKey = kakaoRestApiKey;
    }

    public Map<String, Object> getCoordinatesFromAddress(String address) {
        if (kakaoRestApiKey == null || kakaoRestApiKey.isBlank()) {
            log.warn("KAKAO_REST_API_KEY 미설정 — 주소 좌표 변환 건너뜀 (주소: {})", address);
            return null;
        }
        try {
            String url = "https://dapi.kakao.com/v2/local/search/address.json";
            
            URI uri = UriComponentsBuilder.fromHttpUrl(url)
                    .queryParam("query", address)
                    .build()
                    .encode()
                    .toUri();

            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "KakaoAK " + kakaoRestApiKey);
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
