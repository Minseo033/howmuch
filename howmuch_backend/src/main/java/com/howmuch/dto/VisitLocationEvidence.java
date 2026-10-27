package com.howmuch.dto;

/** Server-calculated distance and GPS accuracy; raw coordinates are not persisted. */
public record VisitLocationEvidence(double distanceMeters, double accuracyMeters) {
    public static final double MAX_DISTANCE_METERS = 100.0;
    public static final double MAX_ACCURACY_METERS = 100.0;

    public VisitLocationEvidence {
        if (!Double.isFinite(distanceMeters) || distanceMeters < 0 || distanceMeters > MAX_DISTANCE_METERS
                || !Double.isFinite(accuracyMeters) || accuracyMeters < 0 || accuracyMeters > MAX_ACCURACY_METERS) {
            throw new IllegalArgumentException("유효한 매장 100m 이내 위치 확인이 필요합니다.");
        }
    }
}
