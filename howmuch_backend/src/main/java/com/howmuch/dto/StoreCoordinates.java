package com.howmuch.dto;

/** 서버가 보유한 방문 인증용 매장 정보. */
public record StoreCoordinates(
        double latitude,
        double longitude,
        String storeId,
        String storeName,
        String industry) {

    public StoreCoordinates(double latitude, double longitude) {
        this(latitude, longitude, null, null, null);
    }
}
