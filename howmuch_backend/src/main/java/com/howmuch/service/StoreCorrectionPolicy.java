package com.howmuch.service;

import com.howmuch.dto.ReportApprovalRequest;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/** Pure, typed moderation rules shared by transaction and tests. Original records remain immutable. */
public final class StoreCorrectionPolicy {
    private StoreCorrectionPolicy() {}
    public record Decision(String resolution, String reason, Map<String, Object> fields) {}

    public static boolean informationReport(Map<String, Object> report) {
        return "STORE_INFO".equalsIgnoreCase(text(report.get("reportType")));
    }
    public static boolean priceReport(Map<String, Object> report) {
        return !informationReport(report) && !text(report.get("changeType")).isBlank();
    }
    public static long revision(Map<String, Object> store) {
        Object revision = store.get("correctionRevision");
        return revision instanceof Number number ? number.longValue() : 0L;
    }

    public static Decision decide(Map<String, Object> report, Map<String, Object> current,
                                  ReportApprovalRequest approval) {
        boolean info = informationReport(report);
        if (current == null) throw new IllegalArgumentException("대상 매장을 찾을 수 없습니다.");
        if (info) {
            if (approval == null || approval.getExpectedRevision() == null
                    || approval.getBefore() == null || approval.getAfter() == null) {
                throw new IllegalArgumentException("수정 종류와 변경 전후 내용을 확인해주세요.");
            }
            if (approval.getExpectedRevision() != revision(current)) {
                throw new IllegalStateException("매장 정보가 변경되었습니다. 새로 조회한 뒤 다시 검토해주세요.");
            }
            if (approval.getBefore().isEmpty()) throw new IllegalArgumentException("변경 전 내용이 필요합니다.");
            for (var item : approval.getBefore().entrySet()) {
                if (!reviewableField(item.getKey())) throw new IllegalArgumentException("변경 전 항목이 올바르지 않습니다.");
                if (!sameValue(current.get(item.getKey()), item.getValue())) {
                    throw new IllegalStateException("검토 중 매장 정보가 변경되었습니다. 다시 조회해주세요.");
                }
            }
        }
        String resolution = info ? text(approval.getResolution()).toUpperCase(java.util.Locale.ROOT) : "PRICE";
        String reason = info ? text(approval.getReviewReason()) : "승인된 가격 변동 제보 반영";
        if (reason.isBlank() || reason.length() > 1000) throw new IllegalArgumentException("검토 사유를 1~1000자로 입력해주세요.");
        Map<String, Object> after = info ? approval.getAfter() : Map.of();
        Map<String, Object> patch = new HashMap<>();
        switch (resolution) {
            case "NO_CHANGE" -> { }
            case "CLOSED" -> {
                if (!Boolean.TRUE.equals(after.get("isClosed"))) throw new IllegalArgumentException("폐업 여부를 확인해주세요.");
                requireBefore(approval, List.of("isClosed"));
                patch.put("isClosed", true);
            }
            case "LOCATION" -> {
                String address = text(after.get("address"));
                Double lat = number(after.get("latitude"));
                Double lng = number(after.get("longitude"));
                if (address.isBlank() || address.length() > 300 || lat == null || lng == null
                        || Math.abs(lat) > 90 || Math.abs(lng) > 180 || lat == 0 || lng == 0) {
                    throw new IllegalArgumentException("수정 주소와 올바른 좌표가 필요합니다.");
                }
                requireBefore(approval, List.of("address", "latitude", "longitude"));
                patch.put("address", address); patch.put("latitude", lat); patch.put("longitude", lng);
            }
            case "PRICE" -> {
                String menu = text(info ? after.get("menu") : report.get("menu1"));
                int slot = info ? integer(after.get("menuSlot")) : slotFor(current, menu, "new".equals(report.get("changeType")));
                if (slot < 1 || slot > 4 || menu.isBlank() || menu.length() > 100) {
                    throw new IllegalArgumentException("변경할 메뉴를 확인해주세요. 등록할 수 있는 메뉴는 최대 4개입니다.");
                }
                for (int other = 1; other <= 4; other++) {
                    if (other != slot && menu.equals(text(current.get("menu" + other)))) {
                        throw new IllegalArgumentException("다른 메뉴 항목에 이미 등록된 이름입니다.");
                    }
                }
                if (info) requireBefore(approval, List.of("menu" + slot, "price" + slot, "free" + slot));
                if (!info && "delete".equals(report.get("changeType"))) {
                    patch.put("menu" + slot, ""); patch.put("price" + slot, ""); patch.put("free" + slot, false);
                } else {
                    Object raw = info ? after.get("price") : report.get("price1");
                    boolean free = Boolean.TRUE.equals(info ? after.get("free") : report.get("free1"));
                    var value = WonPrice.parse(raw).filter(WonPrice.Value::exact).orElseThrow(
                            () -> new IllegalArgumentException("제보 가격은 하나의 정확한 금액으로 입력해주세요."));
                    if ((free && value.minimum() != 0) || (!free && value.minimum() <= 0)) {
                        throw new IllegalArgumentException("무료라고 명시한 메뉴만 0원을 승인할 수 있습니다.");
                    }
                    if (!info && List.of("rise", "drop").contains(text(report.get("changeType")))) {
                        var previous = WonPrice.parse(current.get("price" + slot)).filter(WonPrice.Value::exact)
                                .orElseThrow(() -> new IllegalStateException("현재 가격이 복수값입니다. 정보 신고에서 정확한 변경을 검토해주세요."));
                        long delta = value.minimum() - previous.minimum();
                        if (delta == 0 || ("rise".equals(report.get("changeType")) && delta < 0)
                                || ("drop".equals(report.get("changeType")) && delta > 0)) {
                            throw new IllegalStateException("현재 가격과 제보의 변동 방향이 맞지 않습니다. 다시 검토해주세요.");
                        }
                    }
                    patch.put("menu" + slot, menu); patch.put("price" + slot, Long.toString(value.minimum()));
                    patch.put("free" + slot, free);
                }
            }
            default -> throw new IllegalArgumentException("수정 종류는 PRICE, LOCATION, CLOSED, NO_CHANGE 중 선택해주세요.");
        }
        return new Decision(resolution, reason, Map.copyOf(patch));
    }

    public static void validateNewStorePrices(Map<String, Object> report) {
        boolean menuPresent = false;
        for (int slot = 1; slot <= 4; slot++) {
            String menu = text(report.get("menu" + slot));
            String price = text(report.get("price" + slot));
            boolean free = Boolean.TRUE.equals(report.get("free" + slot));
            if (menu.isBlank() && price.isBlank() && !free) continue;
            menuPresent = true;
            var parsed = WonPrice.parse(price).filter(WonPrice.Value::exact).orElseThrow(
                    () -> new IllegalArgumentException("메뉴 가격은 하나의 정확한 금액으로 입력해주세요."));
            if (menu.isBlank() || (free ? parsed.minimum() != 0 : parsed.minimum() <= 0)) {
                throw new IllegalArgumentException("메뉴와 양수 가격을 입력해주세요. 무료 메뉴만 0원을 허용합니다.");
            }
        }
        if (!menuPresent) throw new IllegalArgumentException("메뉴와 가격을 하나 이상 입력해주세요.");
    }

    private static int slotFor(Map<String, Object> store, String menu, boolean newMenu) {
        for (int slot = 1; slot <= 4; slot++) {
            if (menu.equals(text(store.get("menu" + slot)))) {
                if (newMenu) throw new IllegalStateException("이미 등록된 메뉴입니다.");
                return slot;
            }
        }
        if (newMenu) for (int slot = 1; slot <= 4; slot++) if (text(store.get("menu" + slot)).isBlank()) return slot;
        return 0;
    }
    private static void requireBefore(ReportApprovalRequest approval, List<String> fields) {
        if (approval == null || !approval.getBefore().keySet().containsAll(fields)) {
            throw new IllegalArgumentException("수정 항목의 변경 전 내용을 모두 확인해주세요.");
        }
    }
    private static boolean reviewableField(String field) {
        return List.of("storeId", "storeName", "address", "latitude", "longitude", "isClosed", "correctionRevision").contains(field)
                || field.matches("(?:menu|price|free)[1-4]");
    }
    private static boolean sameValue(Object first, Object second) {
        if (first == null && (second == null || "".equals(second) || Boolean.FALSE.equals(second))) return true;
        if (first instanceof Number && second instanceof Number) return Objects.equals(number(first), number(second));
        return Objects.equals(first, second);
    }
    private static String text(Object value) { return value == null ? "" : value.toString().trim(); }
    private static Double number(Object value) {
        try { double result = Double.parseDouble(text(value)); return Double.isFinite(result) ? result : null; }
        catch (NumberFormatException exception) { return null; }
    }
    private static int integer(Object value) { Double number = number(value); return number != null && number == Math.rint(number) ? number.intValue() : 0; }
}
