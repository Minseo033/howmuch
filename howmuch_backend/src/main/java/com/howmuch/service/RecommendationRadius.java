package com.howmuch.service;

/** Shared API contract: nearby recommendations never expand the requested area. */
public final class RecommendationRadius {
    public static final int DEFAULT_METERS = 3_000;
    private RecommendationRadius() {}

    public static int resolve(Integer meters) {
        int radius = meters == null ? DEFAULT_METERS : meters;
        if (radius < 1_000 || radius > 15_000 || radius % 1_000 != 0) {
            throw new IllegalArgumentException("추천 거리는 1~15km에서 1km 단위로 선택해주세요.");
        }
        return radius;
    }
}
