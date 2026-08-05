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
public class FeedResponseDto {
    private String id;
    private String location;
    private String title;
    private String author;
    private int likes;
    private int comments;
    private String status;
    private List<String> imageUrls;
    private String createdAt;
}
