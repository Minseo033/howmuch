package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder(toBuilder = true)
@NoArgsConstructor
@AllArgsConstructor
public class FeedResponseDto {
    private String id;
    private String location;
    private String title;
    private String author;
    private String authorProfileImageUrl;
    private int likes;
    private int comments;
    private String status;
    private List<String> imageUrls;
    private String createdAt;
    private String storeName;
    private String menu;
    private String price;
    private boolean free;
    /** 계약 C2: 가격 변동 제보 유형(rise|drop|new|delete), 일반 매장 제보는 null */
    private String changeType;
    /** 계약 C2: 제보 종류(예: STORE_INFO), 일반 제보는 null */
    private String reportType;
    /** 계약 C2: 시·도(주소 변환 결과). 없으면 null. location(구)은 그대로 유지합니다. */
    private String cityProvince;
    /** 로그인한 요청자가 좋아요한 글인지. 비로그인·조회 실패 시 false입니다. */
    private boolean likedByMe;
}
