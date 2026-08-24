package com.howmuch.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class KakaoLocalService {

    // 💡 카카오 REST API 키는 환경변수(KAKAO_REST_API_KEY)로만 주입합니다 (레포 public — 하드코딩 금지)
    private final String kakaoRestApiKey;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Autowired
    public KakaoLocalService(
            @Value("${kakao.rest-api-key:}") String kakaoRestApiKey,
            @Value("${kakao.local.timeout-ms:5000}") long timeoutMillis) {
        this(kakaoRestApiKey, new RestTemplateBuilder()
                .connectTimeout(Duration.ofMillis(Math.max(1_000L, timeoutMillis)))
                .readTimeout(Duration.ofMillis(Math.max(1_000L, timeoutMillis)))
                .build());
    }

    KakaoLocalService(String kakaoRestApiKey, RestTemplate restTemplate) {
        this.kakaoRestApiKey = kakaoRestApiKey;
        this.restTemplate = restTemplate;
    }

    public Map<String, Object> getCoordinatesFromAddress(String address) {
        if (kakaoRestApiKey == null || kakaoRestApiKey.isBlank()) {
            log.warn("KAKAO_REST_API_KEY 미설정 - 주소 좌표 변환 건너뜀");
            return null;
        }
        if (address == null || address.isBlank() || address.trim().length() > 300) {
            return null;
        }
        try {
            String url = "https://dapi.kakao.com/v2/local/search/address.json";
            
            URI uri = UriComponentsBuilder.fromHttpUrl(url)
                    .queryParam("query", address.trim())
                    .build()
                    .encode()
                    .toUri();

            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "KakaoAK " + kakaoRestApiKey);

            HttpEntity<String> entity = new HttpEntity<>(headers);
            ResponseEntity<String> response = restTemplate.exchange(uri, HttpMethod.GET, entity, String.class);

            if (!response.getStatusCode().is2xxSuccessful() || response.getBody() == null) {
                return null;
            }
            JsonNode root = objectMapper.readTree(response.getBody());
            JsonNode documents = root.path("documents");

            if (documents.isArray() && documents.size() > 0) {
                JsonNode firstDoc = documents.get(0);
                JsonNode addrNode = firstDoc.path("address");

                double lon = firstDoc.path("x").asDouble(Double.NaN);
                double lat = firstDoc.path("y").asDouble(Double.NaN);
                if (!Double.isFinite(lat) || !Double.isFinite(lon)
                        || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
                    return null;
                }
                
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
            log.warn("주소 좌표 변환 요청에 실패했습니다: {}", e.getClass().getSimpleName());
        }
        return null;
    }

    /** 클라이언트에 REST 키를 노출하지 않는 주소 자동완성 프록시. */
    public List<String> searchAddressSuggestions(String query) {
        if (kakaoRestApiKey == null || kakaoRestApiKey.isBlank()
                || query == null || query.trim().length() < 2 || query.trim().length() > 100) {
            return List.of();
        }
        try {
            URI uri = UriComponentsBuilder
                    .fromHttpUrl("https://dapi.kakao.com/v2/local/search/address.json")
                    .queryParam("query", query.trim())
                    .queryParam("size", 8)
                    .build()
                    .encode()
                    .toUri();
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "KakaoAK " + kakaoRestApiKey);
            ResponseEntity<String> response = restTemplate.exchange(
                    uri, HttpMethod.GET, new HttpEntity<>(headers), String.class);
            if (!response.getStatusCode().is2xxSuccessful() || response.getBody() == null) {
                return List.of();
            }
            JsonNode documents = objectMapper.readTree(response.getBody()).path("documents");
            if (!documents.isArray()) return List.of();
            LinkedHashSet<String> addresses = new LinkedHashSet<>();
            for (JsonNode document : documents) {
                String address = document.path("address_name").asText("").trim();
                if (!address.isBlank()) addresses.add(address);
            }
            return new ArrayList<>(addresses);
        } catch (Exception e) {
            log.warn("주소 자동완성 요청에 실패했습니다: {}", e.getClass().getSimpleName());
            return List.of();
        }
    }

    /** 좌표를 사용자가 읽을 수 있는 행정동 주소와 짧은 동네명으로 변환합니다. */
    public Map<String, String> getRegionFromCoordinates(double latitude, double longitude) {
        if (kakaoRestApiKey == null || kakaoRestApiKey.isBlank()
                || !Double.isFinite(latitude) || !Double.isFinite(longitude)
                || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            return null;
        }
        try {
            URI uri = UriComponentsBuilder
                    .fromHttpUrl("https://dapi.kakao.com/v2/local/geo/coord2regioncode.json")
                    .queryParam("x", longitude)
                    .queryParam("y", latitude)
                    .build()
                    .encode()
                    .toUri();
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "KakaoAK " + kakaoRestApiKey);
            ResponseEntity<String> response = restTemplate.exchange(
                    uri, HttpMethod.GET, new HttpEntity<>(headers), String.class);
            if (!response.getStatusCode().is2xxSuccessful() || response.getBody() == null) {
                return null;
            }
            JsonNode documents = objectMapper.readTree(response.getBody()).path("documents");
            if (!documents.isArray() || documents.isEmpty()) return null;
            JsonNode chosen = documents.get(0);
            for (JsonNode document : documents) {
                if ("H".equals(document.path("region_type").asText())) {
                    chosen = document;
                    break;
                }
            }
            String address = chosen.path("address_name").asText("").trim();
            String label = chosen.path("region_3depth_name").asText("").trim();
            if (address.isBlank()) return null;
            return Map.of("address", address, "label", label.isBlank() ? address : label);
        } catch (Exception e) {
            log.warn("좌표 행정동 변환 요청에 실패했습니다: {}", e.getClass().getSimpleName());
            return null;
        }
    }
}
