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
}
