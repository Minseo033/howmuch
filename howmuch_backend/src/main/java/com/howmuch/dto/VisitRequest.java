package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 서버의 방문 기록 구성 및 이전 앱 요청 호환 DTO (직접 생성 API는 차단됨)
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
    private String verificationMethod; // 신규 기록은 LOCATION_RECEIPT, 기존 LOCATION/RECEIPT_OCR은 조회 호환
    private Double verificationDistanceMeters; // 영수증 접수 시 서버가 계산한 거리
    private Double latitude;    // 인증 시점 사용자 위도
    private Double longitude;   // 인증 시점 사용자 경도
    private Double locationAccuracyMeters; // 인증 시점 위치 정확도
}
