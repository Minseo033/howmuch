package com.howmuch.service;

import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.test.util.ReflectionTestUtils;
import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Locale;
import java.util.Map;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.junit.jupiter.api.Assertions.assertTimeout;

class SonarInputSafetyTest {
    @Test void priceParserRejectsAdversarialAndUnicodeDigitsWithoutBacktracking() {
        assertTimeout(Duration.ofSeconds(5), () -> {
            assertThat(WonPrice.parse(" ".repeat(100_000) + "x")).isEmpty();
            assertThat(WonPrice.parse("0".repeat(100_000) + "/3000").orElseThrow().amounts())
                    .containsExactly(0L, 3000L);
            assertThat(WonPrice.parse("1,000,".repeat(20_000))).isEmpty();
            assertThat(WonPrice.parse("３０００")).isEmpty();
            assertThat(WonPrice.parse("٣٠٠٠")).isEmpty();
            assertThat(WonPrice.parse(null)).isEmpty();
            assertThat(WonPrice.parse("3000 〜 4000원").orElseThrow().range()).isTrue();
            assertThat(WonPrice.parse("3000 – 4000원").orElseThrow().maximum()).isEqualTo(4000L);
        });
    }

    @Test void cloudinaryValidatesLongPathsWithoutStackRecursion() {
        assertTimeout(Duration.ofSeconds(5), () -> {
            String path = "segment/".repeat(10_000) + "leaf";
            assertThat(new CloudinaryReportImageStorage("", "/" + path + "/")).isNotNull();
            assertThatThrownBy(() -> new CloudinaryReportImageStorage("", path + "//leaf"))
                    .isInstanceOf(IllegalArgumentException.class);
            assertThatThrownBy(() -> new CloudinaryReportImageStorage("", "/".repeat(100_000)))
                    .isInstanceOf(IllegalArgumentException.class);
        });
    }

    @Test void ocrNullPathsAndLocaleCannotApproveAMissingStoreOrMenu() {
        var service = new ReceiptOcrService();
        LocalDate today = LocalDate.of(2026, 10, 22);
        assertThat(service.analyzeText(null, null, null, 3000L, today).storeMatch()).isFalse();
        assertThat(service.analyzeText("합계 3,000원", null, 3000L, today).storeMatch()).isFalse();
        assertThat(service.matchesMenu("김밥 3,000원", null)).isFalse();
        Locale original = Locale.getDefault();
        try {
            Locale.setDefault(Locale.forLanguageTag("tr-TR"));
            assertThat(service.analyzeText("pizza\n2026-10-22\n합계 3,000원", "PIZZA", 3000L, today)
                    .storeMatch()).isTrue();
        } finally { Locale.setDefault(original); }
        var cash = service.analyzeText("식당\n2026-10-22\n김밥 3,000원\n받은 돈 10,000원\n거스름돈 7,000원",
                "식당", "김밥", 10_000L, today);
        assertThat(cash.detectedPrice()).isNotEqualTo(10_000L);
        assertThat(cash.shouldAutoApprove()).isFalse();
    }

    @Test void numericRecommendationParsingIsBoundedAndDoesNotWrapLongs() {
        var service = new GeminiService("", 1000, false);
        assertTimeout(Duration.ofSeconds(5), () -> {
            String adversarial = "9".repeat(100_000) + "x";
            assertThat((Integer) ReflectionTestUtils.invokeMethod(service, "requestedRecommendationCount", adversarial))
                    .isEqualTo(3);
            assertThat((Integer) ReflectionTestUtils.invokeMethod(service, "requestedBudgetWon", adversarial)).isNull();
            assertThat((Integer) ReflectionTestUtils.invokeMethod(service, "requestedBudgetWon", "9223372036854776천원"))
                    .isNull();
            assertThat((Integer) ReflectionTestUtils.invokeMethod(service, "requestedBudgetWon", "1만2천원"))
                    .isEqualTo(12000);
            assertThat(service.menuMatchesIntent("김밥,".repeat(10_000), "김밥", Map.of())).isTrue();
            assertThat(service.menuMatchesIntent("김밥,커피빼고", "김밥", Map.of())).isFalse();
            assertThat(service.menuMatchesIntent("김밥빼지마", "김밥", Map.of())).isTrue();
        });
    }

    @Test void ocrRestoresInterruptionWhileKeepingManualFallback() {
        var service = new ReceiptOcrService();
        ReflectionTestUtils.setField(service, "apiKey", "test-not-a-real-key");
        ReflectionTestUtils.setField(service, "endpoint", "http://127.0.0.1:9/");
        Thread.currentThread().interrupt();
        try {
            assertThat(service.analyze(new byte[]{1}, "식당", 3000L).providerAvailable()).isFalse();
            assertThat(Thread.currentThread().isInterrupted()).isTrue();
        } finally { Thread.interrupted(); }
    }

    @Test void emailValidationKeepsTheExistingAsciiWhitespaceContract() {
        var oldPattern = java.util.regex.Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$");
        for (String email : new String[]{"a@b.c", "a.b@c.d.e", "a@..b", "a@b.", "a@@b.c",
                "a b@c.d", "a@b\tc.d", "a@b.c\n", "a@b", "a@.b", "한글@도메인.한국"}) {
            boolean valid = Boolean.TRUE.equals(ReflectionTestUtils.invokeMethod(
                    com.howmuch.controller.UserController.class, "isValidEmail", email));
            assertThat(valid).as(email).isEqualTo(oldPattern.matcher(email).matches());
        }
        assertTimeout(Duration.ofSeconds(5), () -> assertThat(Boolean.TRUE.equals(ReflectionTestUtils.invokeMethod(
                com.howmuch.controller.UserController.class, "isValidEmail", "a@" + ".".repeat(100_000))))
                .isFalse());
    }

    @Test void springSelectsTheBundledHoursConstructor() {
        try (var context = new AnnotationConfigApplicationContext()) {
            context.register(StoreHoursCatalog.class);
            context.refresh();
            assertThat(context.getBean(StoreHoursCatalog.class)).isNotNull();
        }
    }

    @Test void arrayRecordsHaveValueEqualityAndDefensiveCopies() throws Exception {
        Class<?> cidrType = Class.forName("com.howmuch.config.ClientIpResolver$Cidr");
        Constructor<?> ctor = cidrType.getDeclaredConstructor(byte[].class, int.class);
        ctor.setAccessible(true);
        byte[] network = {127, 0, 0, 1};
        Object cidr = ctor.newInstance(network, 32);
        Object sameCidr = ctor.newInstance(network.clone(), 32);
        network[0] = 1;
        assertRecordValue(cidrType, cidr, sameCidr, "network", (byte) 127);
        Class<?> requestType = Class.forName("com.howmuch.service.WeatherService$WeatherRequest");
        Constructor<?> requestCtor = requestType.getDeclaredConstructor(double.class, double.class,
                int[].class, LocalDateTime.class, String.class);
        requestCtor.setAccessible(true);
        int[] grid = {60, 127};
        LocalDateTime base = LocalDateTime.of(2026, 10, 22, 11, 0);
        Object request = requestCtor.newInstance(37.5, 127.0, grid, base, "key");
        Object sameRequest = requestCtor.newInstance(37.5, 127.0, grid.clone(), base, "key");
        grid[0] = 1;
        assertRecordValue(requestType, request, sameRequest, "grid", 60);
    }

    private void assertRecordValue(Class<?> type, Object value, Object equalValue, String accessor, Number first)
            throws Exception {
        assertThat(value).isEqualTo(equalValue).hasSameHashCodeAs(equalValue);
        assertThat(value.toString()).isEqualTo(equalValue.toString()).doesNotContain("[B@", "[I@");
        Method method = type.getDeclaredMethod(accessor);
        method.setAccessible(true);
        Object copy = method.invoke(value);
        if (copy instanceof byte[] bytes) {
            assertThat(bytes[0]).isEqualTo(first.byteValue());
            bytes[0] = 42;
            assertThat(((byte[]) method.invoke(value))[0]).isEqualTo(first.byteValue());
        } else {
            int[] ints = (int[]) copy;
            assertThat(ints[0]).isEqualTo(first.intValue());
            ints[0] = 42;
            assertThat(((int[]) method.invoke(value))[0]).isEqualTo(first.intValue());
        }
        assertThat(value).isEqualTo(equalValue).hasSameHashCodeAs(equalValue);
    }
}
