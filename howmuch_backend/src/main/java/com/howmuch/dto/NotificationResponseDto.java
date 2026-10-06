package com.howmuch.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 알림 응답 DTO
 * GET /api/notifications
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NotificationResponseDto {
    private String id;
    private String title;
    private String body;
    private String type;
    // Lombok은 boolean isRead를 "read"로 직렬화하므로, 프론트 명세 키(isRead)로 고정
    @JsonProperty("isRead")
    private boolean isRead;
    private String createdAt;
    /** 계약 C3: 알림 대상(없으면 null). 앱이 알림을 누르면 해당 게시글·제보·매장으로 이동합니다. */
    private String relatedPostId;
    private String relatedReportId;
    private String storeId;
}
