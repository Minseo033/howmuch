package com.howmuch.service;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;

/** Owner-facing fields. Moderation identities/reasons and correction internals stay private. */
public final class UserReportResponsePolicy {
    private UserReportResponsePolicy() {}
    private static final Set<String> OWNER_FIELDS = Set.of(
        "storeId", "cityProvince", "cityDistrict", "industry", "storeName", "phoneNumber", "address",
        "menu1", "price1", "free1", "menu2", "price2", "free2",
        "menu3", "price3", "free3", "menu4", "price4", "free4",
        "latitude", "longitude", "imageUrls", "reporterId", "visitedRecently", "checkedMenuPrice",
        "changeType", "description", "reportType", "status", "createdAt", "rejectReason", "resolution");
    public static Map<String, Object> ownerView(String id, Map<String, Object> document) {
        Map<String, Object> result = new HashMap<>();
        OWNER_FIELDS.forEach(key -> {
            if (document.containsKey(key)) result.put(key, document.get(key));
        });
        putPreviousPrice(result, document);
        result.put("id", id);
        return result;
    }

    /**
     * QA 2026-10-07 #15: 승인된 가격 변동 제보가 바꾼 메뉴 칸의 반영 전 가격입니다. 승인 직전 매장에
     * 공개돼 있던 값이라 제보자에게 보여도 됩니다. 그 칸의 가격·무료 여부만 꺼내고 previousFields 전체와
     * 나머지 검토 기록은 계속 내보내지 않습니다. 비어 있던 칸(신규 메뉴)과 반영 기록이 없는 옛 승인 건은 넣지 않습니다.
     */
    private static void putPreviousPrice(Map<String, Object> result, Map<String, Object> document) {
        if (!"APPROVED".equalsIgnoreCase(String.valueOf(document.get("status")))
                || !StoreCorrectionPolicy.priceReport(document)
                || !(document.get("previousFields") instanceof Map<?, ?> previous)) return;
        int slot = 0;
        for (int candidate = 1; candidate <= 4; candidate++) {
            if (!previous.containsKey("price" + candidate)) continue;
            if (slot != 0) return; // 승인은 메뉴 한 칸만 바꿉니다. 여러 칸이면 어느 가격인지 정하지 않습니다.
            slot = candidate;
        }
        if (slot == 0) return;
        Object rawPrice = previous.get("price" + slot);
        String price = rawPrice == null ? "" : rawPrice.toString().trim();
        boolean free = Boolean.TRUE.equals(previous.get("free" + slot));
        if (price.isEmpty() && !free) return;
        result.put("previousPrice", price);
        result.put("previousFree", free);
    }
}
