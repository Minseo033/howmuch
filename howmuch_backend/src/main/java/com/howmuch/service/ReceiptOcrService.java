package com.howmuch.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Optional Google Cloud Vision adapter. Missing credentials safely fall back to manual review. */
@Slf4j
@Service
public class ReceiptOcrService {
    private static final Pattern LABELED_PRICE = Pattern.compile(
            "(?:합계|총액|결제금액|받을금액|승인금액|총\\s*결제금액)[^0-9]{0,20}([0-9][0-9,]{2,})",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern PRICE_CANDIDATE = Pattern.compile(
            "(?<![0-9])([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{3,7})(?![0-9])");

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(java.time.Duration.ofSeconds(5))
            .build();

    @Value("${receipt.ocr.api-key:}")
    private String apiKey;

    @Value("${receipt.ocr.endpoint:https://vision.googleapis.com/v1/images:annotate}")
    private String endpoint;

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
            String url = endpoint + "?key=" + URLEncoder.encode(apiKey, StandardCharsets.UTF_8);
            HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                    .header("Content-Type", "application/json")
                    .timeout(java.time.Duration.ofSeconds(15))
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
                log.warn("Receipt OCR provider returned an error: {}", first.path("error").path("message").asText());
                return Result.unavailable("OCR_PROVIDER_ERROR");
            }
            String text = first.path("fullTextAnnotation").path("text").asText("").trim();
            if (text.isBlank()) {
                text = first.path("textAnnotations").path(0).path("description").asText("").trim();
            }
            long detectedPrice = extractPrice(text);
            boolean storeMatch = matchesStore(text, storeName);
            boolean priceMatch = detectedPrice > 0 && detectedPrice == submittedPrice;
            int score = (text.isBlank() ? 0 : 20) + (storeMatch ? 40 : 0) + (priceMatch ? 40 : 0);
            return new Result(true, text.length(), detectedPrice, storeMatch, priceMatch, score,
                    score >= 100 ? "AUTO_APPROVED_CANDIDATE" : "MANUAL_REVIEW");
        } catch (Exception e) {
            log.warn("Receipt OCR failed; keeping manual review fallback", e);
            return Result.unavailable("OCR_PROVIDER_ERROR");
        }
    }

    private long extractPrice(String text) {
        Matcher labeled = LABELED_PRICE.matcher(text);
        long labeledPrice = 0;
        while (labeled.find()) {
            labeledPrice = Math.max(labeledPrice, parseAmount(labeled.group(1)));
        }
        if (labeledPrice > 0) return labeledPrice;

        Matcher candidates = PRICE_CANDIDATE.matcher(text);
        long largest = 0;
        while (candidates.find()) {
            largest = Math.max(largest, parseAmount(candidates.group(1)));
        }
        return largest;
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
        String[] tokens = normalizedStore.split(" ");
        long matched = java.util.Arrays.stream(tokens)
                .filter(token -> token.length() >= 2 && normalizedText.contains(token))
                .count();
        return tokens.length > 1 && matched * 2 >= tokens.length;
    }

    private String normalize(String value) {
        return value == null ? "" : value.toLowerCase().replaceAll("[^가-힣a-z0-9]", "");
    }

    public record Result(
            boolean providerAvailable,
            int detectedTextLength,
            long detectedPrice,
            boolean storeMatch,
            boolean priceMatch,
            int score,
            String status) {
        static Result unavailable(String status) {
            return new Result(false, 0, 0, false, false, 0, status);
        }

        public boolean shouldAutoApprove() {
            return providerAvailable && score >= 100 && storeMatch && priceMatch;
        }
    }
}
