package com.howmuch.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.io.InputStream;

/** 한국소비자원 참가격의 최신 지역별 외식비·개인서비스요금을 조회하고 캐시합니다. */
@Slf4j
@Service
public class TruePriceService {

    static final String DINE_OUT_URL =
            "https://price.go.kr/tprice/portal/servicepriceinfo/dineoutprice/dineOutPriceList.do";
    static final String PERSONAL_SERVICE_URL =
            "https://price.go.kr/tprice/portal/servicepriceinfo/serviceindustryprice/serviceIndustryPriceList.do";

    private static final List<String> DINE_OUT_ITEMS = List.of(
            "냉면", "비빔밥", "김치찌개백반", "삼겹살환산전", "삼겹살", "자장면", "삼계탕", "칼국수", "김밥");
    private static final List<String> PERSONAL_SERVICE_ITEMS = List.of(
            "세탁", "숙박", "이용", "미용", "목욕");

    private final HttpClient httpClient;
    private final Duration requestTimeout;
    private volatile Snapshot snapshot = Snapshot.empty();

    public TruePriceService(
            @Value("${true-price.timeout-ms:8000}") long timeoutMillis) {
        requestTimeout = Duration.ofMillis(Math.max(1000L, timeoutMillis));
        httpClient = HttpClient.newBuilder()
                .connectTimeout(requestTimeout)
                .followRedirects(HttpClient.Redirect.NORMAL)
                .build();
        loadBundledSnapshot();
    }

    @Async
    @EventListener(ApplicationReadyEvent.class)
    void loadOnStartup() {
        refresh();
    }

    @Scheduled(
            initialDelayString = "${true-price.refresh-initial-delay-ms:60000}",
            fixedDelayString = "${true-price.refresh-delay-ms:86400000}")
    public void refresh() {
        try {
            ParsedTable dineOut = fetchTable(DINE_OUT_URL, "지역별 외식비 정보", DINE_OUT_ITEMS);
            ParsedTable personal = fetchTable(
                    PERSONAL_SERVICE_URL, "개인서비스 요금 정보", PERSONAL_SERVICE_ITEMS);
            Map<String, Map<String, Long>> merged = new HashMap<>();
            mergeInto(merged, dineOut.values());
            mergeInto(merged, personal.values());
            String basisDate = dineOut.basisDate().compareTo(personal.basisDate()) <= 0
                    ? dineOut.basisDate() : personal.basisDate();
            snapshot = new Snapshot(Map.copyOf(merged), basisDate);
            log.info("참가격 지역별 기준가 갱신 완료: 기준월={}, 지역={}개", basisDate, merged.size());
        } catch (Exception error) {
            log.warn("참가격 갱신 실패로 기존 캐시를 유지합니다: {}", error.getClass().getSimpleName());
        }
    }

    public Optional<ReferencePrices.Estimate> estimate(String menu, String industry, String address) {
        String item = matchOfficialItem(menu, industry);
        if (item == null) return Optional.empty();

        Snapshot current = snapshot;
        if (current.values().isEmpty()) return Optional.empty();
        String region = resolveRegion(address);
        Long price = region == null ? null : valueForRegion(current.values(), region, item);
        String label;
        int sampleSize;
        if (price != null) {
            label = "참가격 " + region + " 평균";
            sampleSize = 1;
        } else {
            List<Long> nationwide = current.values().values().stream()
                    .map(values -> values.get(item))
                    .filter(java.util.Objects::nonNull)
                    .sorted(Comparator.naturalOrder())
                    .toList();
            if (nationwide.isEmpty()) return Optional.empty();
            price = median(nationwide);
            label = "참가격 전국 지역값 중앙값";
            sampleSize = nationwide.size();
        }
        return Optional.of(new ReferencePrices.Estimate(
                price, "TRUE_PRICE", label, current.basisDate(), sampleSize));
    }

    private void loadBundledSnapshot() {
        try (InputStream input = TruePriceService.class.getResourceAsStream(
                "/true-price-snapshot.json")) {
            if (input == null) return;
            JsonNode root = new ObjectMapper().readTree(input);
            Map<String, Map<String, Long>> values = new HashMap<>();
            root.path("values").fields().forEachRemaining(region -> {
                Map<String, Long> prices = new HashMap<>();
                region.getValue().fields().forEachRemaining(item ->
                        prices.put(item.getKey(), item.getValue().asLong()));
                values.put(region.getKey(), Map.copyOf(prices));
            });
            if (!values.isEmpty()) {
                snapshot = new Snapshot(Map.copyOf(values), root.path("basisDate").asText(""));
            }
        } catch (Exception error) {
            log.warn("내장 참가격 스냅샷을 읽지 못했습니다: {}", error.getClass().getSimpleName());
        }
    }

    ParsedTable parseTable(String html, String captionText, List<String> itemNames) {
        Document document = Jsoup.parse(html);
        Element table = document.select("table").stream()
                .filter(candidate -> {
                    Element caption = candidate.selectFirst("caption");
                    return caption != null && caption.text().contains(captionText);
                })
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("참가격 표를 찾을 수 없습니다."));

        Map<String, Map<String, Long>> values = new LinkedHashMap<>();
        for (Element row : table.select("tbody tr")) {
            Elements cells = row.select("td");
            if (cells.size() < itemNames.size() + 1) continue;
            String region = normalizeRegion(cells.get(0).text());
            if (region.isBlank()) continue;
            Map<String, Long> prices = new LinkedHashMap<>();
            for (int index = 0; index < itemNames.size(); index++) {
                Long price = parsePrice(cells.get(index + 1).text());
                if (price != null) prices.put(itemNames.get(index), price);
            }
            if (!prices.isEmpty()) values.put(region, Map.copyOf(prices));
        }
        if (values.isEmpty()) throw new IllegalArgumentException("참가격 가격 행이 비어 있습니다.");

        Element year = document.selectFirst("#searchYear option[selected]");
        Element month = document.selectFirst("#searchMonth option[selected]");
        String basisDate = year != null && month != null
                ? year.attr("value") + "-" + month.attr("value") : "";
        return new ParsedTable(Map.copyOf(values), basisDate);
    }

    private ParsedTable fetchTable(String url, String caption, List<String> items) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                .timeout(requestTimeout)
                .header("User-Agent", "HowMuch/1.0 public-price-refresh")
                .GET()
                .build();
        HttpResponse<String> response = httpClient.send(
                request, HttpResponse.BodyHandlers.ofString(java.nio.charset.StandardCharsets.UTF_8));
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IllegalStateException("참가격 HTTP " + response.statusCode());
        }
        return parseTable(response.body(), caption, items);
    }

    private static void mergeInto(
            Map<String, Map<String, Long>> target,
            Map<String, Map<String, Long>> source) {
        source.forEach((region, prices) -> {
            Map<String, Long> merged = new HashMap<>(target.getOrDefault(region, Map.of()));
            merged.putAll(prices);
            target.put(region, Map.copyOf(merged));
        });
    }

    static String matchOfficialItem(String menu, String industry) {
        String value = ReferencePrices.normalize(menu);
        if (value.contains("냉면")) return "냉면";
        if (value.contains("비빔밥")) return "비빔밥";
        if (value.contains("김치찌개")) return "김치찌개백반";
        if (value.contains("삼겹살")) return "삼겹살";
        if (value.contains("자장면")) return "자장면";
        if (value.contains("삼계탕")) return "삼계탕";
        if (value.contains("칼국수")) return "칼국수";
        if (value.contains("김밥")) return "김밥";

        String category = ReferencePrices.normalize(industry);
        if (category.contains("세탁") && (value.contains("세탁") || value.contains("드라이"))) return "세탁";
        if (category.contains("숙박") && (value.contains("숙박") || value.contains("1박") || value.contains("객실"))) return "숙박";
        if (category.contains("이용") && (value.contains("커트") || value.contains("컷") || value.contains("이발"))) return "이용";
        if (category.contains("미용") && (value.contains("커트") || value.contains("컷"))) return "미용";
        if (category.contains("목욕") && (value.contains("목욕") || value.contains("대중탕") || value.contains("입욕"))) return "목욕";
        return null;
    }

    static String resolveRegion(String address) {
        if (address == null || address.isBlank()) return null;
        Map<String, String> aliases = Map.ofEntries(
                Map.entry("서울", "서울"), Map.entry("부산", "부산"), Map.entry("대구", "대구"),
                Map.entry("인천", "인천"), Map.entry("광주", "광주"), Map.entry("대전", "대전"),
                Map.entry("울산", "울산"), Map.entry("세종", "세종"), Map.entry("경기", "경기"),
                Map.entry("강원", "강원"), Map.entry("충북", "충북"), Map.entry("충청북", "충북"),
                Map.entry("충남", "충남"), Map.entry("충청남", "충남"), Map.entry("전북", "전북"),
                Map.entry("전라북", "전북"), Map.entry("전남", "전남"), Map.entry("전라남", "전남"),
                Map.entry("경북", "경북"), Map.entry("경상북", "경북"), Map.entry("경남", "경남"),
                Map.entry("경상남", "경남"), Map.entry("제주", "제주"));
        return aliases.entrySet().stream()
                .filter(entry -> address.startsWith(entry.getKey()))
                .map(Map.Entry::getValue)
                .findFirst()
                .orElse(null);
    }

    private static Long valueForRegion(
            Map<String, Map<String, Long>> values, String region, String item) {
        return values.entrySet().stream()
                .filter(entry -> entry.getKey().contains(region))
                .map(entry -> entry.getValue().get(item))
                .filter(java.util.Objects::nonNull)
                .findFirst()
                .orElse(null);
    }

    private static String normalizeRegion(String value) {
        return value == null ? "" : value.replaceAll("\\s+", "").replace("특별자치도", "");
    }

    private static Long parsePrice(String value) {
        String digits = value == null ? "" : value.replaceAll("[^0-9]", "");
        if (digits.isEmpty()) return null;
        try {
            long parsed = Long.parseLong(digits);
            return parsed > 0 && parsed <= 10_000_000L ? parsed : null;
        } catch (NumberFormatException ignored) {
            return null;
        }
    }

    private static long median(List<Long> values) {
        int size = values.size();
        return size % 2 == 1
                ? values.get(size / 2)
                : values.get(size / 2 - 1) + (values.get(size / 2) - values.get(size / 2 - 1)) / 2;
    }

    record ParsedTable(Map<String, Map<String, Long>> values, String basisDate) {}
    record Snapshot(Map<String, Map<String, Long>> values, String basisDate) {
        static Snapshot empty() {
            return new Snapshot(Map.of(), "");
        }
    }
}
