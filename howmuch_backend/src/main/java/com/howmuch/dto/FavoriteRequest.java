package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 찜하기 추가 요청 DTO
 * POST /api/favorites
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FavoriteRequest {
    private String storeId;     // 매장 ID (필수)
    private String storeName;   // 매장명 (표시용, 선택)
}