package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatResponse {
    private String response;
    private boolean fallback;
    private List<String> recommendedStoreIds;
    private List<Map<String, Object>> recommendations;
    private Integer radiusMeters;
}
