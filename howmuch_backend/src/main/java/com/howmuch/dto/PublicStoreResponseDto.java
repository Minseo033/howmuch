package com.howmuch.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;
import java.util.List;

@Data
public class PublicStoreResponseDto {
    
    @JsonProperty("totalCount")
    private int totalCount;
    
    @JsonProperty("data")
    private List<StoreItem> data;

    @Data
    public static class StoreItem {
        @JsonProperty("시도")
        private String cityProvince;

        @JsonProperty("시군")
        private String cityDistrict;

        @JsonProperty("업종")
        private String industry;

        @JsonProperty("업소명")
        private String storeName;

        @JsonProperty("연락처")
        private String phoneNumber;

        @JsonProperty("주소")
        private String address;

        @JsonProperty("메뉴1")
        private String menu1;
        @JsonProperty("가격1")
        private String price1;
        
        @JsonProperty("메뉴2")
        private String menu2;
        @JsonProperty("가격2")
        private String price2;

        @JsonProperty("메뉴3")
        private String menu3;
        @JsonProperty("가격3")
        private String price3;

        @JsonProperty("메뉴4")
        private String menu4;
        @JsonProperty("가격4")
        private String price4;
    }
}
