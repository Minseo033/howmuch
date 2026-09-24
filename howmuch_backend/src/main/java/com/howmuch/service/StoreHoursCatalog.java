package com.howmuch.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/** Reviewed hours are independent of the government snapshot and never require per-request DB reads. */
@Service
@Slf4j
public class StoreHoursCatalog {
    private static final Map<String, String> REGIONAL_SOURCES = Map.of(
            "부산광역시 서구 착한가격업소", "/data/15051967/fileData.do",
            "울산광역시 착한가격업소", "/data/15083262/fileData.do",
            "울산광역시 남구 착한가격업소", "/data/3069400/fileData.do",
            "강원특별자치도 동해시 착한가격업소", "/data/3077962/fileData.do",
            "경상남도 산청군 착한가격업소", "/data/15089937/fileData.do",
            "경기도 동두천시 착한가격업소", "/data/3072002/fileData.do"
    );
    private final Map<String, Entry> entries;

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Entry(String storeId, String storeName, String address, String phoneNumber,
                        String status, String text, String sourceName, String sourceUrl, String checkedAt,
                        Boolean parkingYn, Boolean packingYn, String areaCurrency,
                        List<String> imageUrls) {
        boolean valid() {
            try {
                URI uri = URI.create(sourceUrl);
                return storeId != null && storeId.matches("store_[a-f0-9]{24}")
                        && storeName != null && !storeName.isBlank()
                        && address != null && !address.isBlank()
                        && "SOURCE_VERIFIED".equals(status)
                        && text != null && !text.isBlank() && text.length() <= 1000
                        && !text.contains("<") && !text.contains(">")
                        && "https".equals(uri.getScheme()) && uri.getUserInfo() == null
                        && uri.getPort() == -1
                        && (("행정안전부 착한가격업소".equals(sourceName)
                                && "www.goodprice.go.kr".equals(uri.getHost())
                                && "/bssh/bsshInfo.do".equals(uri.getPath())
                                && uri.getQuery() != null && uri.getQuery().matches("bsshSn=\\d+"))
                            || (REGIONAL_SOURCES.containsKey(sourceName)
                                && "www.data.go.kr".equals(uri.getHost())
                                && REGIONAL_SOURCES.get(sourceName).equals(uri.getPath())
                                && uri.getQuery() == null))
                        && checkedAt.matches("\\d{4}-\\d{2}-\\d{2}")
                        && !LocalDate.parse(checkedAt).isAfter(LocalDate.now(ZoneId.of("Asia/Seoul")));
            } catch (RuntimeException e) {
                return false;
            }
        }

        Map<String, Object> publicData() {
            Map<String, Object> map = new HashMap<>();
            map.put("status", status);
            map.put("text", text);
            map.put("sourceName", sourceName);
            map.put("sourceUrl", sourceUrl);
            map.put("checkedAt", checkedAt);
            if (parkingYn != null) map.put("parkingYn", parkingYn);
            if (packingYn != null) map.put("packingYn", packingYn);
            if (areaCurrency != null && !areaCurrency.isBlank()) map.put("areaCurrency", areaCurrency);
            if (imageUrls != null && !imageUrls.isEmpty()) map.put("imageUrls", imageUrls);
            return Collections.unmodifiableMap(map);
        }
    }

    public StoreHoursCatalog() {
        this(readEntries());
    }

    StoreHoursCatalog(List<Entry> records) {
        Map<String, Entry> loaded = new HashMap<>();
        var duplicates = new java.util.HashSet<String>();
        for (Entry entry : records) {
            if (entry == null || !entry.valid()) continue;
            if (loaded.putIfAbsent(entry.storeId(), entry) != null) duplicates.add(entry.storeId());
        }
        // A conflicting pair must not silently select whichever happened to be first.
        duplicates.forEach(loaded::remove);
        entries = Map.copyOf(loaded);
        log.info("출처 검토된 영업시간 {}건을 로드했습니다.", entries.size());
    }

    private static List<Entry> readEntries() {
        try (var input = new ClassPathResource("store-hours.json").getInputStream()) {
            return new ObjectMapper().readValue(input, new TypeReference<>() {});
        } catch (Exception e) {
            log.warn("영업시간 자료를 읽지 못해 기본 매장 정보만 제공합니다: {}", e.getClass().getSimpleName());
            return List.of();
        }
    }

    public Map<String, Object> findFor(Map<String, Object> store) {
        Entry entry = entries.get(String.valueOf(store.get("storeId")));
        // A stale ID, moved branch, or changed phone must not inherit another store's hours.
        if (entry == null || !Objects.equals(entry.storeName(), store.get("storeName"))
                || !Objects.equals(entry.address(), store.get("address"))
                || !Objects.equals(Objects.toString(entry.phoneNumber(), ""), Objects.toString(store.get("phoneNumber"), ""))) {
            return null;
        }
        return entry.publicData();
    }
}
