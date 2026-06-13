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
public class UserReportRequest {
    // 💡 stores 테이블과 동일한 기본 구조
    private String cityProvince;
    private String cityDistrict;
    private String industry;
    private String storeName;
    private String phoneNumber;
    private String address;
    private String menu1;
    private String price1;
    private String menu2;
    private String price2;
    private String menu3;
    private String price3;
    private String menu4;
    private String price4;
    private double latitude;
    private double longitude;

    // 💡 제보 데이터만의 추가 메타데이터
    private List<String> imageUrls;
    private String reporterId;
    private boolean visitedRecently;
    private boolean checkedMenuPrice;
}
