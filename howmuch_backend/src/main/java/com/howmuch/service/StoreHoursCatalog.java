package com.howmuch.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/** Reviewed hours are independent of the government snapshot and never require per-request DB reads. */
@Service
@Slf4j
public class StoreHoursCatalog {
    private final Map<String, Entry> entries;

    public record Entry(String storeId, String storeName, String address, String phoneNumber,
                        String status, String text, String sourceName, String sourceUrl, String checkedAt) {
        boolean valid() {
            try {
                URI uri = URI.create(sourceUrl);
                return storeId != null && storeId.matches("store_[a-f0-9]{24}")
                        && storeName != null && !storeName.isBlank()
                        && address != null && !address.isBlank()
                        && "SOURCE_VERIFIED".equals(status)
                        && text != null && !text.isBlank() && text.length() <= 1000
                        && !text.contains("<") && !text.contains(">")
                        && "행정안전부 착한가격업소".equals(sourceName)
                        && "https".equals(uri.getScheme()) && uri.getUserInfo() == null
                        && "www.goodprice.go.kr".equals(uri.getHost()) && uri.getPort() == -1
                        && "/bssh/bsshInfo.do".equals(uri.getPath())
                        && uri.getQuery() != null && uri.getQuery().matches("bsshSn=\\d+")
                        && checkedAt.matches("\\d{4}-\\d{2}-\\d{2}")
                        && !LocalDate.parse(checkedAt).isAfter(LocalDate.now(ZoneId.of("Asia/Seoul")));
            } catch (RuntimeException e) {
                return false;
            }
        }

        Map<String, Object> publicData() {
            return Map.of("status", status, "text", text, "sourceName", sourceName,
                    "sourceUrl", sourceUrl, "checkedAt", checkedAt);
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
