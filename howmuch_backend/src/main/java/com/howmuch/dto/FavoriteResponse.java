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
    // ↓ 공개 매장 카탈로그에서 stable storeId로 매칭한 메타. 찜 목록에서
    // 상세 화면으로 바로 이동해도 전체 카탈로그를 다시 내려받을 필요가 없도록
    // 상세 화면에 쓰이는 필드를 함께 전달한다. 매장이 삭제됐거나 비공개인 경우 null.
    private String industry;    // 업종 (예: 미용업, 음식점)
    private String menu1;       // 대표 메뉴
    private String price1;      // 대표 가격 (문자열, 예: "5000")
    private String menu2;
    private String price2;
    private String menu3;
    private String price3;
    private String menu4;
    private String price4;
    private String address;     // 매장 주소
    private String phoneNumber;
    private Double latitude;
    private Double longitude;
    private String source;      // GOV 또는 USER. 추측해서 GOV로 채우지 않는다.
}
