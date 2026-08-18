package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 방문 인증 생성 요청 DTO (POST /api/visits)
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VisitRequest {
    private String storeId;     // 매장 ID (선택)
    private String storeName;   // 매장명 (필수)
    private String menu;        // 이용 메뉴 (선택)
    private Long price;         // 실제 결제 금액 (원, 필수)
    private String industry;    // 업종 (선택 — 미제공 시 서버가 매장명으로 캐시에서 조회)
    private String verificationMethod; // LOCATION (현재 지원 방식)
    private Double verificationDistanceMeters; // 하위 호환용 입력값 (서버가 다시 계산해 덮어씀)
    private Double latitude;    // 인증 시점 사용자 위도
    private Double longitude;   // 인증 시점 사용자 경도
    private Double locationAccuracyMeters; // 인증 시점 위치 정확도
}
