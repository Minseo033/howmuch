package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReviewRequest {
    private String storeId;
    private String storeName;
    private String authorName;
    private String menu;
    private String content;
    private int stars;
}