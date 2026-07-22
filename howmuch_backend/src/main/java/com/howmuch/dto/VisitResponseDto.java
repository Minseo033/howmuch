package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 방문 기록 응답 DTO
 * (방문 일시, 매장명, 절약 금액 포함)
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VisitResponseDto {
    private String id;          // 방문 기록 ID
    private String storeId;     // 매장 ID
    private String storeName;   // 매장명
    private String visitedAt;   // 방문 일시 (ISO 8601 String)
    private Long savedAmount;   // 절약 금액 (원)
    private String menu;        // 이용 메뉴
    private Long price;         // 결제/이용 금액
    private Boolean isGov;      // 착한가격업소 여부
}
