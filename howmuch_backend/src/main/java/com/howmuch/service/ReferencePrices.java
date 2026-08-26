package com.howmuch.service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

/** 실제 공공데이터 가격 표본을 이용하는 비교가 폴백입니다. */
public final class ReferencePrices {

    private static final int MENU_SLOT_COUNT = 4;

    private ReferencePrices() {}

    public record Estimate(
            long referencePrice,
            String source,
            String label,
            String basisDate,
            int sampleSize) {
        public boolean isMenuLevel() {
            return "TRUE_PRICE".equals(source) || "PUBLIC_STORE_MENU".equals(source);
        }
    }

    /**
     * 착한가격업소의 동일 메뉴 등록가를 우선하고, 없으면 동일 업종 등록가 중앙값을 사용합니다.
     */
    public static Optional<Estimate> estimateFromPublicStores(
            List<Map<String, Object>> stores,
            String menu,
            String industry) {
        if (stores == null || stores.isEmpty()) return Optional.empty();

        String normalizedMenu = normalize(menu);
        List<Long> exact = new ArrayList<>();
        List<Long> related = new ArrayList<>();
        if (!normalizedMenu.isEmpty()) {
            for (Map<String, Object> store : stores) {
                for (int slot = 1; slot <= MENU_SLOT_COUNT; slot++) {
                    String candidate = normalize(store.get("menu" + slot));
                    Long price = parsePrice(store.get("price" + slot));
                    if (candidate.isEmpty() || price == null) continue;
                    if (candidate.equals(normalizedMenu)) {
                        exact.add(price);
                    } else if (candidate.length() >= 2
                            && (candidate.contains(normalizedMenu)
                            || normalizedMenu.contains(candidate))) {
                        related.add(price);
                    }
                }
            }
        }
        List<Long> menuPrices = !exact.isEmpty() ? exact : related;
        if (!menuPrices.isEmpty()) {
            return Optional.of(toEstimate(
                    menuPrices, "PUBLIC_STORE_MENU", "착한가격업소 동일 메뉴 등록가 중앙값"));
        }

        String normalizedIndustry = normalize(industry);
        if (normalizedIndustry.isEmpty()) return Optional.empty();
        List<Long> industryPrices = new ArrayList<>();
        for (Map<String, Object> store : stores) {
            if (!normalize(store.get("industry")).equals(normalizedIndustry)) continue;
            for (int slot = 1; slot <= MENU_SLOT_COUNT; slot++) {
                Long price = parsePrice(store.get("price" + slot));
                if (price != null) industryPrices.add(price);
            }
        }
        if (industryPrices.isEmpty()) return Optional.empty();
        return Optional.of(toEstimate(
                industryPrices, "PUBLIC_STORE_INDUSTRY", "착한가격업소 동일 업종 등록가 중앙값"));
    }

    public static long savedAmount(Optional<Estimate> estimate, long paidPrice) {
        return estimate.map(value -> Math.max(0L, value.referencePrice() - paidPrice)).orElse(0L);
    }

    private static Estimate toEstimate(List<Long> prices, String source, String label) {
        prices.sort(Comparator.naturalOrder());
        int size = prices.size();
        long median = size % 2 == 1
                ? prices.get(size / 2)
                : prices.get(size / 2 - 1) + (prices.get(size / 2) - prices.get(size / 2 - 1)) / 2;
        return new Estimate(median, source, label, "", size);
    }

    static String normalize(Object value) {
        if (value == null) return "";
        return String.valueOf(value)
                .replaceAll("\\s+", "")
                .replace("짜장", "자장")
                .toLowerCase(Locale.ROOT);
    }

    private static Long parsePrice(Object value) {
        if (value == null) return null;
        String digits = String.valueOf(value).replaceAll("[^0-9]", "");
        if (digits.isEmpty()) return null;
        try {
            long price = Long.parseLong(digits);
            return price > 0 && price <= 10_000_000L ? price : null;
        } catch (NumberFormatException ignored) {
            return null;
        }
    }
}
