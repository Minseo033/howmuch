package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 절약 목표 설정 요청 DTO
 * POST /api/savings/goal
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SavingsGoalRequest {
    private Long goalAmount;    // 목표 절약 금액 (원, 필수, 0 이상)
}