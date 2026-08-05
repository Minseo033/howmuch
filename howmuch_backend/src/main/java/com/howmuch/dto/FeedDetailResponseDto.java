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
    private int likes;
    private int comments;
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
    private boolean visitedRecently;
    private boolean checkedMenuPrice;
    private String rejectReason;
}
