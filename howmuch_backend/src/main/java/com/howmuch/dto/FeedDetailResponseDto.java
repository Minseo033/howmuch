package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FeedDetailResponseDto {
    private String id;
    private String location;
    private String title;
    private String author;
    private String authorProfileImageUrl;
    private int likes;
    private int comments;
    private boolean likedByMe;
    private boolean notificationEnabled;
    private String status;
    private List<String> imageUrls;
    private String createdAt;

    // Details from UserReport
    private String storeName;
    private String address;
    private String phoneNumber;
    private String industry;
    private String menu1;
    private String price1;
    private String menu2;
    private String price2;
    private String menu3;
    private String price3;
    private String menu4;
    private String price4;
    private boolean free1;
    private boolean free2;
    private boolean free3;
    private boolean free4;
    private boolean visitedRecently;
    private boolean checkedMenuPrice;
    /** 피드 목록과 같은 의미의 가격 변동 유형·제보 종류·시도(없으면 null) */
    private String changeType;
    private String reportType;
    private String cityProvince;
}
