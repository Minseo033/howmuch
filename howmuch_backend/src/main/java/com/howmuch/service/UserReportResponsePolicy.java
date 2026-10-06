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
        result.put("id", id);
        return result;
    }
}
