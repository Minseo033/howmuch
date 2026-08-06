package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 절약 목표 응답 DTO
 * GET /api/savings/goal
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SavingsGoalResponse {
    private Long goalAmount;    // 목표 절약 금액 (원). 미설정 시 null
    private String updatedAt;   // 마지막 설정 일시 (ISO 8601 String)
}