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
    private String id;          // 찜 문서 ID ({uid}_{storeId})
    private String storeId;     // 매장 ID
    private String storeName;   // 매장명
    private String createdAt;   // 찜한 일시 (ISO 8601 String)
}