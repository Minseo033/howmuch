package com.howmuch.dto;

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
    private boolean isRead;
    private String createdAt;
}
