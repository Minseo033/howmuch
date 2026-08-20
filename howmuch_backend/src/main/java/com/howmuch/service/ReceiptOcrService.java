package com.howmuch.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.time.LocalDate;
import java.time.ZoneId;

/** Optional Google Cloud Vision adapter. Missing credentials safely fall back to manual review. */
@Slf4j
@Service
public class ReceiptOcrService {
    private static final Pattern LABELED_PRICE = Pattern.compile(
            "(?:합계|총액|결제금액|받을금액|승인금액|총\\s*결제금액)[^0-9]{0,20}([0-9][0-9,]{2,})",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern PRICE_CANDIDATE = Pattern.compile(
            "(?<![0-9])([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{3,7})(?![0-9])");
    private static final Pattern RECEIPT_DATE = Pattern.compile(
            "(?<![0-9])(20[0-9]{2}|[0-9]{2})\\s*[./-]\\s*(0?[1-9]|1[0-2])\\s*[./-]\\s*(0?[1-9]|[12][0-9]|3[01])(?![0-9])");
    private static final Pattern KOREAN_RECEIPT_DATE = Pattern.compile(
            "(?<![0-9])(20[0-9]{2}|[0-9]{2})\\s*년\\s*(0?[1-9]|1[0-2])\\s*월\\s*(0?[1-9]|[12][0-9]|3[01])\\s*일");
    private static final ZoneId KOREA_ZONE = ZoneId.of("Asia/Seoul");
    private static final int MAX_AUTO_APPROVAL_AGE_DAYS = 7;

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(java.time.Duration.ofSeconds(5))
            .build();

    @Value("${receipt.ocr.api-key:}")
    private String apiKey;

    @Value("${receipt.ocr.endpoint:https://vision.googleapis.com/v1/images:annotate}")
    private String endpoint;

    @Value("${receipt.ocr.timeout-ms:15000}")
    private long timeoutMs;

    public Result analyze(byte[] imageBytes, String storeName, long submittedPrice) {
        if (imageBytes == null || imageBytes.length == 0) {
            return Result.unavailable("EMPTY_IMAGE");
        }
        if (apiKey == null || apiKey.isBlank()) {
            return Result.unavailable("OCR_NOT_CONFIGURED");
        }

        try {
            String encoded = Base64.getEncoder().encodeToString(imageBytes);
            Map<String, Object> requestBody = Map.of(
                    "requests", List.of(Map.of(
                            "image", Map.of("content", encoded),
                            "features", List.of(Map.of("type", "TEXT_DETECTION")))));
            HttpRequest request = HttpRequest.newBuilder(URI.create(endpoint))
                    .header("X-Goog-Api-Key", apiKey)
                    .header("Content-Type", "application/json")
                    .timeout(java.time.Duration.ofMillis(Math.max(100, timeoutMs)))
                    .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(requestBody)))
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                log.warn("Receipt OCR request failed: status={}", response.statusCode());
                return Result.unavailable("OCR_PROVIDER_ERROR");
            }

            JsonNode root = objectMapper.readTree(response.body());
            JsonNode first = root.path("responses").path(0);
            if (first.has("error")) {
                log.warn("Receipt OCR provider returned an error response");
                return Result.unavailable("OCR_PROVIDER_ERROR");
            }
            String text = first.path("fullTextAnnotation").path("text").asText("").trim();
            if (text.isBlank()) {
                text = first.path("textAnnotations").path(0).path("description").asText("").trim();
            }
            return analyzeText(text, storeName, submittedPrice);
        } catch (Exception e) {
            log.warn("Receipt OCR failed; keeping manual review fallback: {}",
                    e.getClass().getSimpleName());
            return Result.unavailable("OCR_PROVIDER_ERROR");
        }
    }

    Result analyzeText(String text, String storeName, long submittedPrice) {
        return analyzeText(text, storeName, submittedPrice, LocalDate.now(KOREA_ZONE));
    }

    Result analyzeText(
            String text, String storeName, long submittedPrice, LocalDate today) {
        String safeText = text == null ? "" : text.trim();
        PriceExtraction price = extractPrice(safeText);
        ReceiptDateExtraction receiptDate = extractReceiptDate(safeText, today);
        boolean storeMatch = matchesStore(safeText, storeName);
        boolean priceMatch = price.amount() > 0 && price.amount() == submittedPrice;
        int score = (safeText.isBlank() ? 0 : 20)
                + (storeMatch ? 30 : 0)
                + (priceMatch ? 20 : 0)
                + (priceMatch && price.labeled() ? 20 : 0)
                + (receiptDate.plausible() ? 10 : 0);
        boolean autoApprovalCandidate = score >= 100
                && price.labeled() && receiptDate.plausible();
        String status = autoApprovalCandidate
                ? "AUTO_APPROVED_CANDIDATE"
                : receiptDate.date() == null
                        ? "MANUAL_REVIEW_DATE_MISSING"
                        : !receiptDate.plausible()
                                ? "MANUAL_REVIEW_DATE_INVALID"
                                : "MANUAL_REVIEW";
        return new Result(true, safeText.length(), price.amount(), price.labeled(),
                storeMatch, priceMatch,
                receiptDate.date() == null ? null : receiptDate.date().toString(),
                receiptDate.plausible(), score, status);
    }

    private ReceiptDateExtraction extractReceiptDate(String text, LocalDate today) {
        List<LocalDate> candidates = new java.util.ArrayList<>();
        collectDates(RECEIPT_DATE.matcher(text), candidates);
        collectDates(KOREAN_RECEIPT_DATE.matcher(text), candidates);
        if (candidates.isEmpty()) return new ReceiptDateExtraction(null, false);

        LocalDate closest = candidates.stream()
                .min(java.util.Comparator.comparingLong(
                        date -> Math.abs(java.time.temporal.ChronoUnit.DAYS.between(date, today))))
                .orElse(null);
        long ageDays = java.time.temporal.ChronoUnit.DAYS.between(closest, today);
        return new ReceiptDateExtraction(
                closest, ageDays >= 0 && ageDays <= MAX_AUTO_APPROVAL_AGE_DAYS);
    }

    private void collectDates(Matcher matcher, List<LocalDate> target) {
        while (matcher.find()) {
            int year = Integer.parseInt(matcher.group(1));
            if (year < 100) year += 2000;
            try {
                target.add(LocalDate.of(
                        year,
                        Integer.parseInt(matcher.group(2)),
                        Integer.parseInt(matcher.group(3))));
            } catch (java.time.DateTimeException ignored) {
                // OCR이 만든 존재하지 않는 날짜는 후보에서 제외합니다.
            }
        }
    }

    private PriceExtraction extractPrice(String text) {
        Matcher labeled = LABELED_PRICE.matcher(text);
        long labeledPrice = 0;
        while (labeled.find()) {
            labeledPrice = Math.max(labeledPrice, parseAmount(labeled.group(1)));
        }
        if (labeledPrice > 0) return new PriceExtraction(labeledPrice, true);

        Matcher candidates = PRICE_CANDIDATE.matcher(text);
        long largest = 0;
        while (candidates.find()) {
            largest = Math.max(largest, parseAmount(candidates.group(1)));
        }
        return new PriceExtraction(largest, false);
    }

    private long parseAmount(String value) {
        try {
            return Long.parseLong(value.replace(",", ""));
        } catch (NumberFormatException ignored) {
            return 0;
        }
    }

    private boolean matchesStore(String text, String storeName) {
        String normalizedText = normalize(text);
        String normalizedStore = normalize(storeName);
        if (normalizedText.isBlank() || normalizedStore.isBlank()) return false;
        if (normalizedText.contains(normalizedStore)) return true;
        List<String> tokens = java.util.Arrays.stream(storeName.toLowerCase()
                        .split("[^가-힣a-z0-9]+"))
                .map(this::normalize)
                .filter(token -> token.length() >= 2)
                .distinct()
                .toList();
        long matched = tokens.stream()
                .filter(normalizedText::contains)
                .count();
        return tokens.size() > 1 && matched * 2 >= tokens.size();
    }

    private String normalize(String value) {
        return value == null ? "" : value.toLowerCase().replaceAll("[^가-힣a-z0-9]", "");
    }

    public record Result(
            boolean providerAvailable,
            int detectedTextLength,
            long detectedPrice,
            boolean labeledPrice,
            boolean storeMatch,
            boolean priceMatch,
            String detectedDate,
            boolean receiptDatePlausible,
            int score,
            String status) {
        static Result unavailable(String status) {
            return new Result(false, 0, 0, false, false, false,
                    null, false, 0, status);
        }

        public boolean shouldAutoApprove() {
            return providerAvailable && labeledPrice && receiptDatePlausible
                    && score >= 100 && storeMatch && priceMatch;
        }
    }

    private record PriceExtraction(long amount, boolean labeled) {}
    private record ReceiptDateExtraction(LocalDate date, boolean plausible) {}
}
