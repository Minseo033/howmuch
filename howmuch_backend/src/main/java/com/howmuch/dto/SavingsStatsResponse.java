package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 절약 통계 응답 DTO
 * GET /api/savings/stats?period=this_month|last_month|this_year
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SavingsStatsResponse {
    private String period;              // period 구분 (this_month, last_month, this_year)
    private Long totalSavedAmount;      // 기간별 총 절약금액 (원)
    private Long totalVisits;           // 기간별 총 방문 횟수
    private Long averageSavedAmount;    // 방문당 평균 절약금액 (원)
    private String chartTitle;          // 차트 타이틀 ("주차별 절약 금액" 또는 "월별 절약 금액")
    private List<ChartItemDto> chartItems; // 주차/월별 차트 데이터

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ChartItemDto {
        private String label;      // 레이블 (e.g. "1주", "2주" ... 또는 "1월", "2월" ...)
        private Long amount;       // 해당 구간 절약 금액
        private Long count;        // 해당 구간 방문 횟수
        private Boolean isMax;     // 최고 절약 구간 여부
    }
}
