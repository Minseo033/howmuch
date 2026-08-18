package com.howmuch.dto;

/** 서버가 보유한 매장 좌표. 방문 인증 거리 계산에 사용합니다. */
public record StoreCoordinates(double latitude, double longitude) {
}
