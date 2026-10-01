package com.howmuch.service;

import org.junit.jupiter.api.Test;
import com.howmuch.dto.SavingsHistoryResponse;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import static org.assertj.core.api.Assertions.assertThat;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class SavingsServiceValidationTest {

    @Test
    void rejectsUnknownPeriodInsteadOfSilentlyUsingCurrentMonth() {
        FirebaseService firebaseService = mock(FirebaseService.class);
        SavingsService service = new SavingsService(firebaseService);

        assertThrows(IllegalArgumentException.class,
                () -> service.getSavingsStats("user-1", "this_weak"));
        verifyNoInteractions(firebaseService);
    }

    @Test
    void periodRangesHandleMonthYearAndLeapBoundaries() {
        assertThat(SavingsService.periodRange("last_month", LocalDate.of(2024, 3, 1)))
                .isEqualTo(new SavingsService.DateRange(LocalDate.of(2024, 2, 1), LocalDate.of(2024, 3, 1)));
        assertThat(SavingsService.periodRange("last_month", LocalDate.of(2026, 1, 1)))
                .isEqualTo(new SavingsService.DateRange(LocalDate.of(2025, 12, 1), LocalDate.of(2026, 1, 1)));
        assertThat(SavingsService.periodRange("this_year", LocalDate.of(2024, 12, 31)))
                .isEqualTo(new SavingsService.DateRange(LocalDate.of(2024, 1, 1), LocalDate.of(2025, 1, 1)));
    }

    @Test
    void statisticsAndHistoryShareKoreanMidnightExclusiveEnd() throws Exception {
        FirebaseService firebase = mock(FirebaseService.class);
        SavingsService service = new SavingsService(firebase,
                Clock.fixed(Instant.parse("2026-09-30T15:00:00Z"), ZoneOffset.UTC));
        when(firebase.getSavingsHistory("user")).thenReturn(List.of(
                item("last", "2026-09-30T14:59:59Z", 1000L, false),
                item("current", "2026-09-30T15:00:00Z", 2000L, false),
                item("end", "2026-10-31T15:00:00Z", 3000L, false)));
        var stats = service.getSavingsStats("user", "last_month");
        assertThat(stats.getStartDate()).isEqualTo("2026-09-01");
        assertThat(stats.getEndDateExclusive()).isEqualTo("2026-10-01");
        assertThat(stats.getTotalVisits()).isEqualTo(1);
        assertThat(stats.getTotalSavedAmount()).isEqualTo(1000);
        assertThat(service.getSavingsHistory("user", stats.getStartDate(), stats.getEndDateExclusive()))
                .extracting(SavingsHistoryResponse::getId).containsExactly("last");
        var current = service.getSavingsStats("user", "this_month");
        assertThat(current.getTotalSavedAmount()).isEqualTo(2000);
        assertThat(service.getSavingsHistory("user", current.getStartDate(), current.getEndDateExclusive()))
                .extracting(SavingsHistoryResponse::getId).containsExactly("current");
    }

    @Test
    void leapDayCountsAndFreeUsesDoNotInventSavings() throws Exception {
        FirebaseService firebase = mock(FirebaseService.class);
        SavingsService service = new SavingsService(firebase,
                Clock.fixed(Instant.parse("2024-03-01T00:00:00Z"), ZoneOffset.UTC));
        when(firebase.getSavingsHistory("user")).thenReturn(List.of(
                item("leap", "2024-02-29", 1500L, false),
                item("free", "2024-02-29", 999999L, true),
                item("march", "2024-03-01", 2000L, false)));
        var stats = service.getSavingsStats("user", "last_month");
        assertThat(stats.getTotalVisits()).isEqualTo(2);
        assertThat(stats.getTotalSavedAmount()).isEqualTo(1500);
        assertThat(service.getSavingsHistory("user", "2024-02-01", "2024-03-01"))
                .extracting(SavingsHistoryResponse::getId).containsExactly("leap", "free");
    }

    @Test
    void invalidHistoryRangesAreRejectedBeforeDatabaseReads() {
        FirebaseService firebase = mock(FirebaseService.class);
        SavingsService service = new SavingsService(firebase);
        assertThrows(IllegalArgumentException.class, () -> service.getSavingsHistory("user", "2026-10-01", null));
        assertThrows(IllegalArgumentException.class, () -> service.getSavingsHistory("user", "2026-02-29", "2026-03-01"));
        assertThrows(IllegalArgumentException.class, () -> service.getSavingsHistory("user", "2026-10-01", "2026-10-01"));
        assertThrows(IllegalArgumentException.class, () -> service.getSavingsHistory("user", "2026-10-02", "2026-10-01"));
        verifyNoInteractions(firebase);
    }

    private SavingsHistoryResponse item(String id, String date, long saved, boolean free) {
        return SavingsHistoryResponse.builder().id(id).visitedAt(date).savedAmount(saved).isFree(free).build();
    }
}
