package com.howmuch.service;

import com.howmuch.dto.SavingsHistoryResponse;
import com.howmuch.dto.SavingsStatsResponse;
import com.howmuch.dto.SavingsStatsResponse.ChartItemDto;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 절약 서비스 레이어.
 * visits 컬렉션을 기반으로 사용자의 절약 내역 및 절약 통계 조회 비즈니스 로직을 처리합니다.
 */
@Slf4j
@Service
public class SavingsService {

    private static final ZoneId KOREA_ZONE = ZoneId.of("Asia/Seoul");
    private static final java.util.Set<String> SUPPORTED_PERIODS =
            java.util.Set.of("this_month", "last_month", "this_year");
    private final FirebaseService firebaseService;
    private final Clock clock;

    @Autowired
    public SavingsService(FirebaseService firebaseService) {
        this(firebaseService, Clock.system(KOREA_ZONE));
    }

    SavingsService(FirebaseService firebaseService, Clock clock) {
        this.firebaseService = firebaseService;
        this.clock = java.util.Objects.requireNonNull(clock).withZone(KOREA_ZONE);
    }

    public record DateRange(LocalDate startDate, LocalDate endDateExclusive) {
        public boolean contains(LocalDate date) {
            return date != null && !date.isBefore(startDate) && date.isBefore(endDateExclusive);
        }
    }

    public static DateRange periodRange(String period, LocalDate today) {
        return switch (period) {
            case "this_month" -> new DateRange(today.withDayOfMonth(1), today.withDayOfMonth(1).plusMonths(1));
            case "last_month" -> new DateRange(today.withDayOfMonth(1).minusMonths(1), today.withDayOfMonth(1));
            case "this_year" -> new DateRange(LocalDate.of(today.getYear(), 1, 1), LocalDate.of(today.getYear() + 1, 1, 1));
            default -> throw new IllegalArgumentException("지원하지 않는 절약 통계 기간입니다.");
        };
    }

    /**
     * 사용자의 절약 내역 목록 조회 (GET /api/savings/history)
     *
     * @param firebaseUid 인증된 사용자 UID
     * @return 절약 내역 DTO 목록 (최신순)
     */
    public List<SavingsHistoryResponse> getSavingsHistory(String firebaseUid) throws Exception {
        if (firebaseUid == null || firebaseUid.isBlank()) {
            return List.of();
        }
        return firebaseService.getSavingsHistory(firebaseUid);
    }

    public List<SavingsHistoryResponse> getSavingsHistory(
            String firebaseUid, String startDate, String endDateExclusive) throws Exception {
        if (startDate == null && endDateExclusive == null) return getSavingsHistory(firebaseUid);
        if (startDate == null || endDateExclusive == null
                || !startDate.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}")
                || !endDateExclusive.matches("[0-9]{4}-[0-9]{2}-[0-9]{2}")) {
            throw new IllegalArgumentException("조회 시작 날짜와 종료 날짜를 YYYY-MM-DD 형식으로 함께 입력해주세요.");
        }
        final DateRange range;
        try {
            range = new DateRange(LocalDate.parse(startDate), LocalDate.parse(endDateExclusive));
        } catch (java.time.DateTimeException exception) {
            throw new IllegalArgumentException("올바른 조회 날짜를 입력해주세요.");
        }
        if (!range.startDate().isBefore(range.endDateExclusive())) {
            throw new IllegalArgumentException("조회 종료 날짜는 시작 날짜 이후여야 합니다.");
        }
        return getSavingsHistory(firebaseUid).stream()
                .filter(item -> range.contains(itemDate(item))).toList();
    }

    /**
     * 기간별 절약 통계 및 차트 데이터 집계 반환 (GET /api/savings/stats?period=this_month|last_month|this_year)
     *
     * @param firebaseUid 인증된 사용자 UID
     * @param period 기간 구분 (this_month, last_month, this_year)
     * @return 절약 통계 DTO
     */
    public SavingsStatsResponse getSavingsStats(String firebaseUid, String period) throws Exception {
        String targetPeriod = (period != null && !period.isBlank()) ? period.trim().toLowerCase() : "this_month";
        if (!SUPPORTED_PERIODS.contains(targetPeriod)) {
            throw new IllegalArgumentException("지원하지 않는 절약 통계 기간입니다.");
        }

        List<SavingsHistoryResponse> history = getSavingsHistory(firebaseUid);

        LocalDate now = LocalDate.now(clock);
        DateRange range = periodRange(targetPeriod, now);

        if ("last_month".equals(targetPeriod)) {
            YearMonth lastMonth = YearMonth.from(range.startDate());
            return aggregateMonthlyStats(history, lastMonth, "last_month");
        } else if ("this_year".equals(targetPeriod)) {
            int currentYear = range.startDate().getYear();
            return aggregateYearlyStats(history, currentYear, "this_year");
        } else {
            // 기본값: this_month
            YearMonth thisMonth = YearMonth.from(range.startDate());
            return aggregateMonthlyStats(history, thisMonth, "this_month");
        }
    }

    private SavingsStatsResponse aggregateMonthlyStats(List<SavingsHistoryResponse> history, YearMonth yearMonth, String periodKey) {
        // 주차별(1주~5주) 집계 Map 준비
        Map<Integer, Long> amountMap = new LinkedHashMap<>();
        Map<Integer, Long> countMap = new LinkedHashMap<>();
        for (int w = 1; w <= 5; w++) {
            amountMap.put(w, 0L);
            countMap.put(w, 0L);
        }

        long totalSaved = 0L;
        long totalVisits = 0L;

        for (SavingsHistoryResponse item : history) {
            LocalDate date = itemDate(item);
            if (date == null) continue;

            if (YearMonth.from(date).equals(yearMonth)) {
                long saved = savedAmount(item);
                int weekNum = Math.min((date.getDayOfMonth() - 1) / 7 + 1, 5); // 1~5주차

                totalSaved += saved;
                totalVisits += 1;

                amountMap.put(weekNum, amountMap.get(weekNum) + saved);
                countMap.put(weekNum, countMap.get(weekNum) + 1);
            }
        }

        long maxAmount = amountMap.values().stream().mapToLong(Long::longValue).max().orElse(0L);

        List<ChartItemDto> chartItems = new ArrayList<>();
        for (int w = 1; w <= 5; w++) {
            long amt = amountMap.get(w);
            long cnt = countMap.get(w);
            boolean isMax = (amt > 0 && amt == maxAmount);

            chartItems.add(ChartItemDto.builder()
                    .label(w + "주")
                    .amount(amt)
                    .count(cnt)
                    .isMax(isMax)
                    .build());
        }

        long avgSaved = totalVisits > 0 ? totalSaved / totalVisits : 0L;

        return SavingsStatsResponse.builder()
                .period(periodKey)
                .startDate(yearMonth.atDay(1).toString())
                .endDateExclusive(yearMonth.plusMonths(1).atDay(1).toString())
                .totalSavedAmount(totalSaved)
                .totalVisits(totalVisits)
                .averageSavedAmount(avgSaved)
                .chartTitle("주차별 절약 금액")
                .chartItems(chartItems)
                .build();
    }

    private SavingsStatsResponse aggregateYearlyStats(List<SavingsHistoryResponse> history, int year, String periodKey) {
        // 월별(1월~12월) 집계 Map 준비
        Map<Integer, Long> amountMap = new LinkedHashMap<>();
        Map<Integer, Long> countMap = new LinkedHashMap<>();
        for (int m = 1; m <= 12; m++) {
            amountMap.put(m, 0L);
            countMap.put(m, 0L);
        }

        long totalSaved = 0L;
        long totalVisits = 0L;

        for (SavingsHistoryResponse item : history) {
            LocalDate date = itemDate(item);
            if (date == null) continue;

            if (date.getYear() == year) {
                long saved = savedAmount(item);
                int monthNum = date.getMonthValue(); // 1~12월

                totalSaved += saved;
                totalVisits += 1;

                amountMap.put(monthNum, amountMap.get(monthNum) + saved);
                countMap.put(monthNum, countMap.get(monthNum) + 1);
            }
        }

        long maxAmount = amountMap.values().stream().mapToLong(Long::longValue).max().orElse(0L);

        List<ChartItemDto> chartItems = new ArrayList<>();
        for (int m = 1; m <= 12; m++) {
            long amt = amountMap.get(m);
            long cnt = countMap.get(m);
            boolean isMax = (amt > 0 && amt == maxAmount);

            chartItems.add(ChartItemDto.builder()
                    .label(m + "월")
                    .amount(amt)
                    .count(cnt)
                    .isMax(isMax)
                    .build());
        }

        long avgSaved = totalVisits > 0 ? totalSaved / totalVisits : 0L;

        return SavingsStatsResponse.builder()
                .period(periodKey)
                .startDate(LocalDate.of(year, 1, 1).toString())
                .endDateExclusive(LocalDate.of(year + 1, 1, 1).toString())
                .totalSavedAmount(totalSaved)
                .totalVisits(totalVisits)
                .averageSavedAmount(avgSaved)
                .chartTitle("월별 절약 금액")
                .chartItems(chartItems)
                .build();
    }

    private LocalDate itemDate(SavingsHistoryResponse item) {
        if (item == null) return null;
        LocalDate date = parseDate(item.getVisitedAt());
        return date == null ? parseDate(item.getDate()) : date;
    }

    private long savedAmount(SavingsHistoryResponse item) {
        if (Boolean.TRUE.equals(item.getIsFree())) return 0L;
        return item.getSavedAmount() == null ? 0L : Math.max(0L, item.getSavedAmount());
    }

    static LocalDate parseDate(String dateStr) {
        if (dateStr == null || dateStr.isBlank()) return null;
        String s = dateStr.trim();
        try {
            if (s.contains("T")) {
                return ZonedDateTime.parse(s)
                        .withZoneSameInstant(KOREA_ZONE)
                        .toLocalDate();
            }
        } catch (Exception ignored) {}
        try {
            if (s.contains("T")) {
                return LocalDateTime.parse(s).toLocalDate();
            }
        } catch (Exception ignored) {}
        try {
            s = s.replace(".", "-");
            if (s.length() == 10) {
                return LocalDate.parse(s);
            }
        } catch (Exception ignored) {}
        return null;
    }
}
