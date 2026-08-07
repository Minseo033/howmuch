package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 찜하기 항목 응답 DTO
 * GET /api/favorites
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FavoriteResponse {
    private String id;          // 찜 문서 ID ({uid}_{storeId} — storeId는 '/' 이스케이프됨)
    private String storeId;     // 매장 ID
    private String storeName;   // 매장명
    private String createdAt;   // 찜한 일시 (ISO 8601 String)
    // ↓ 공공데이터 인메모리 캐시에서 매장명으로 매칭된 매장 메타 (제보 매장 등 캐시 미스 시 null)
    private String industry;    // 업종 (예: 미용업, 음식점)
    private String menu1;       // 대표 메뉴
    private String price1;      // 대표 가격 (문자열, 예: "5000")
    private String address;     // 매장 주소
}