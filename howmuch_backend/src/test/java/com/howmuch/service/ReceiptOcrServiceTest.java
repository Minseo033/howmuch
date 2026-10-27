package com.howmuch.service;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;

class ReceiptOcrServiceTest {

    private final ReceiptOcrService service = new ReceiptOcrService();

    @Test
    void autoApprovesOnlyALabeledTotalWithMatchingStoreAndPrice() {
        ReceiptOcrService.Result result = service.analyzeText(
                "왕비집 시청무교점\n2026.08.19\n총 결제금액 8,000원",
                "왕비집 시청무교점",
                8_000L,
                LocalDate.of(2026, 8, 19));

        assertThat(result.labeledPrice()).isTrue();
        assertThat(result.storeMatch()).isTrue();
        assertThat(result.priceMatch()).isTrue();
        assertThat(result.detectedDate()).isEqualTo("2026-08-19");
        assertThat(result.receiptDatePlausible()).isTrue();
        assertThat(result.shouldAutoApprove()).isTrue();
    }

    @Test
    void matchesMeaningfulStoreTokensAfterNormalizingWhitespace() {
        ReceiptOcrService.Result result = service.analyzeText(
                "왕비집\n26년 8월 18일\n합계 12,000원",
                "왕비집 시청무교점",
                12_000L,
                LocalDate.of(2026, 8, 19));

        assertThat(result.storeMatch()).isTrue();
        assertThat(result.shouldAutoApprove()).isTrue();
    }

    @Test
    void rejectsAutoApprovalWhenSubmittedMenuDoesNotMatchReceiptText() {
        ReceiptOcrService.Result mismatch = service.analyzeText(
                "캠퍼스분식\n2026-10-14\n김밥 4,000원\n합계 4,000원",
                "캠퍼스분식",
                "삼계탕",
                4_000L,
                LocalDate.of(2026, 10, 16));

        assertThat(mismatch.storeMatch()).isTrue();
        assertThat(mismatch.priceMatch()).isTrue();
        assertThat(mismatch.menuMatch()).isFalse();
        assertThat(mismatch.score()).isLessThan(100);
        assertThat(mismatch.status()).isEqualTo("MANUAL_REVIEW_MENU_MISMATCH");
        assertThat(mismatch.shouldAutoApprove()).isFalse();

        ReceiptOcrService.Result matched = service.analyzeText(
                "캠퍼스분식\n2026-10-14\n김밥 4,000원\n합계 4,000원",
                "캠퍼스분식",
                "김밥",
                4_000L,
                LocalDate.of(2026, 10, 16));

        assertThat(matched.menuMatch()).isTrue();
        assertThat(matched.score()).isEqualTo(100);
        assertThat(matched.shouldAutoApprove()).isTrue();

        ReceiptOcrService.Result promoBypassAttempt = service.analyzeText(
                "캠퍼스분식\n2026-10-14\n김밥 4,000원\n합계 4,000원\n다음주 삼계탕 행사",
                "캠퍼스분식",
                "삼계탕",
                4_000L,
                LocalDate.of(2026, 10, 16));
        assertThat(promoBypassAttempt.menuMatch()).isFalse();
        assertThat(promoBypassAttempt.shouldAutoApprove()).isFalse();
    }

    @Test
    void prioritizesActualApprovedOrPaidAmountOverPreDiscountTotal() {
        ReceiptOcrService.Result result = service.analyzeText(
                "캠퍼스분식\n2026-10-14\n합계 10,000원\n할인 2,000원\n승인금액 8,000원",
                "캠퍼스분식",
                "돈까스",
                8_000L,
                LocalDate.of(2026, 10, 16));

        assertThat(result.detectedPrice()).isEqualTo(8_000L);
        assertThat(result.labeledPrice()).isTrue();
        assertThat(result.priceMatch()).isTrue();

        ReceiptOcrService.Result cashReceipt = service.analyzeText(
                "캠퍼스분식\n2026-10-14\n돈까스 8,000원\n결제액 8,000원\n받은 돈 10,000원\n거스름돈 2,000원",
                "캠퍼스분식",
                "돈까스",
                8_000L,
                LocalDate.of(2026, 10, 16));
        assertThat(cashReceipt.detectedPrice()).isEqualTo(8_000L);
        assertThat(cashReceipt.priceMatch()).isTrue();
        assertThat(cashReceipt.shouldAutoApprove()).isTrue();
    }

    @Test
    void keepsUnlabeledNumberMatchesForManualReview() {
        ReceiptOcrService.Result result = service.analyzeText(
                "테스트 식당\n사업자번호 123456",
                "테스트 식당",
                123_456L);

        assertThat(result.priceMatch()).isTrue();
        assertThat(result.labeledPrice()).isFalse();
        assertThat(result.status()).isEqualTo("MANUAL_REVIEW_DATE_MISSING");
        assertThat(result.shouldAutoApprove()).isFalse();
    }

    @Test
    void sendsMissingOrOldReceiptDatesToManualReview() {
        ReceiptOcrService.Result missing = service.analyzeText(
                "테스트 식당\n합계 8,000원", "테스트 식당", 8_000L,
                LocalDate.of(2026, 8, 19));
        ReceiptOcrService.Result old = service.analyzeText(
                "테스트 식당\n2026-07-01\n합계 8,000원", "테스트 식당", 8_000L,
                LocalDate.of(2026, 8, 19));

        assertThat(missing.status()).isEqualTo("MANUAL_REVIEW_DATE_MISSING");
        assertThat(missing.shouldAutoApprove()).isFalse();
        assertThat(old.detectedDate()).isEqualTo("2026-07-01");
        assertThat(old.status()).isEqualTo("MANUAL_REVIEW_DATE_INVALID");
        assertThat(old.shouldAutoApprove()).isFalse();
    }

    @Test
    void ignoresImpossibleDates() {
        ReceiptOcrService.Result result = service.analyzeText(
                "테스트 식당\n2026-02-31\n합계 8,000원", "테스트 식당", 8_000L,
                LocalDate.of(2026, 8, 19));

        assertThat(result.detectedDate()).isNull();
        assertThat(result.shouldAutoApprove()).isFalse();
    }

    @Test
    void callsTheProviderWithAHeaderKeyAndParsesSuccessfulOcr() throws Exception {
        AtomicReference<String> receivedKey = new AtomicReference<>();
        AtomicReference<String> receivedQuery = new AtomicReference<>();
        String today = LocalDate.now(ZoneId.of("Asia/Seoul")).toString();
        HttpServer server = startServer(exchange -> {
            receivedKey.set(exchange.getRequestHeaders().getFirst("X-Goog-Api-Key"));
            receivedQuery.set(exchange.getRequestURI().getQuery());
            exchange.getRequestBody().readAllBytes();
            sendJson(exchange, 200, "{\"responses\":[{\"fullTextAnnotation\":{\"text\":\"테스트 식당\\n"
                    + today + "\\n합계 8,000원\"}}]}");
        });
        try {
            configureProvider(service, server, 1_000);

            ReceiptOcrService.Result result = service.analyze(
                    "image".getBytes(StandardCharsets.UTF_8), "테스트 식당", 8_000L);

            assertThat(receivedKey.get()).isEqualTo("test-api-key");
            assertThat(receivedQuery.get()).isNull();
            assertThat(result.providerAvailable()).isTrue();
            assertThat(result.shouldAutoApprove()).isTrue();
        } finally {
            server.stop(0);
        }
    }

    @Test
    void fallsBackToManualReviewForProviderErrors() throws Exception {
        HttpServer server = startServer(exchange -> {
            exchange.getRequestBody().readAllBytes();
            sendJson(exchange, 429, "{\"error\":{\"message\":\"quota\"}}");
        });
        try {
            configureProvider(service, server, 1_000);

            ReceiptOcrService.Result result = service.analyze(
                    "image".getBytes(StandardCharsets.UTF_8), "테스트 식당", 8_000L);

            assertThat(result.providerAvailable()).isFalse();
            assertThat(result.status()).isEqualTo("OCR_PROVIDER_ERROR");
            assertThat(result.shouldAutoApprove()).isFalse();
        } finally {
            server.stop(0);
        }
    }

    @Test
    void fallsBackToManualReviewWhenTheProviderTimesOut() throws Exception {
        HttpServer server = startServer(exchange -> {
            try {
                Thread.sleep(300);
                sendJson(exchange, 200, "{\"responses\":[]}");
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });
        try {
            configureProvider(service, server, 100);

            ReceiptOcrService.Result result = service.analyze(
                    "image".getBytes(StandardCharsets.UTF_8), "테스트 식당", 8_000L);

            assertThat(result.providerAvailable()).isFalse();
            assertThat(result.status()).isEqualTo("OCR_PROVIDER_ERROR");
        } finally {
            server.stop(0);
        }
    }

    private HttpServer startServer(com.sun.net.httpserver.HttpHandler handler) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/ocr", handler);
        server.start();
        return server;
    }

    private void configureProvider(
            ReceiptOcrService target, HttpServer server, long timeoutMs) {
        ReflectionTestUtils.setField(target, "apiKey", "test-api-key");
        ReflectionTestUtils.setField(
                target, "endpoint", "http://127.0.0.1:" + server.getAddress().getPort() + "/ocr");
        ReflectionTestUtils.setField(target, "timeoutMs", timeoutMs);
    }

    private void sendJson(
            com.sun.net.httpserver.HttpExchange exchange, int status, String json)
            throws java.io.IOException {
        byte[] body = json.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, body.length);
        exchange.getResponseBody().write(body);
        exchange.close();
    }
}
