package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor  // 💡 Firestore 연동(직렬화)을 위해 필수
@AllArgsConstructor // 💡 @Builder와 함께 사용하기 위해 필요
public class StoreDto {
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
}
