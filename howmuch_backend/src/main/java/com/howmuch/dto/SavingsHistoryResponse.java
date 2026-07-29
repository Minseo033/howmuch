package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 절약 내역 응답 DTO
 * GET /api/savings/history
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SavingsHistoryResponse {
    private String id;          // 방문/절약 기록 ID
    private String storeId;     // 매장 ID
    private String storeName;   // 매장명
    private String visitedAt;   // 방문 일시 (ISO 8601 String)
    private String date;        // 날짜 표현 (visitedAt 동일 또는 포맷팅용)
    private String menu;        // 메뉴명
    private Long price;         // 결제/이용 금액 (원)
    private Long savedAmount;   // 절약 금액 (원)
    private Boolean isGov;      // 착한가격업소 여부 (정부인증 여부)
}
