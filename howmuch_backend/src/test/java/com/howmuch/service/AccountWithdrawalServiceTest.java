package com.howmuch.service;

import org.junit.jupiter.api.Test;
import java.util.List;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class AccountWithdrawalServiceTest {
    private final WithdrawalJobStore jobs = mock(WithdrawalJobStore.class);
    private final FirebaseService data = mock(FirebaseService.class);
    private final SessionTokenService sessions = mock(SessionTokenService.class);
    private static final String ID = "00000000-0000-4000-8000-000000000001";
    private final WithdrawalJobStore.Job job = new WithdrawalJobStore.Job("user", ID, "PENDING", 1, 0, 1, "lease");

    @Test
    void persistFailureCannotRevokeSessionsOrAcknowledgeDeletion() throws Exception {
        when(jobs.submit(eq("user"), eq(ID), anyLong())).thenThrow(new RuntimeException("offline"));
        assertThatThrownBy(() -> new AccountWithdrawalService(jobs, data, sessions).submit("user", ID))
                .isInstanceOf(RuntimeException.class);
        verifyNoInteractions(data, sessions);
    }

    @Test
    void partialDeletionStaysPendingAndAFreshServerRetriesItToCompletion() throws Exception {
        when(jobs.pending()).thenReturn(List.of(job));
        when(jobs.claim(eq(job), anyLong())).thenReturn(job);
        when(data.deleteUser("user")).thenThrow(new RuntimeException("image/Firestore timeout"))
                .thenReturn(java.util.Map.of("uid", "user"));
        new AccountWithdrawalService(jobs, data, sessions).retryPending();
        verify(jobs).finish(eq(job), eq(false), anyLong());
        verify(jobs, never()).finish(eq(job), eq(true), anyLong());

        new AccountWithdrawalService(jobs, data, sessions).retryPending();
        verify(data, times(2)).deleteUser("user");
        verify(jobs).finish(eq(job), eq(true), anyLong());
        verify(sessions).forgetRevocation("user");
    }

    @Test
    void anotherWorkerHoldingTheLeasePreventsDuplicateDeletion() throws Exception {
        when(jobs.pending()).thenReturn(List.of(job));
        new AccountWithdrawalService(jobs, data, sessions).retryPending();
        verifyNoInteractions(data, sessions);
    }

    @Test
    void failedCompletionWriteNeverConfirmsCompletionAndReleasesForRetry() throws Exception {
        when(jobs.claim(eq(job), anyLong())).thenReturn(job);
        doThrow(new RuntimeException("write failed")).when(jobs).finish(eq(job), eq(true), anyLong());
        new AccountWithdrawalService(jobs, data, sessions).process(job);
        verify(jobs).finish(eq(job), eq(false), anyLong());
        verify(sessions, never()).forgetRevocation(any());
    }
}
