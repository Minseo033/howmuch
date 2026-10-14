package com.howmuch.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class AccountWithdrawalService {
    private final WithdrawalJobStore jobs;
    private final FirebaseService data;
    private final SessionTokenService sessions;

    public AccountWithdrawalService(WithdrawalJobStore jobs, FirebaseService data, SessionTokenService sessions) {
        this.jobs = jobs;
        this.data = data;
        this.sessions = sessions;
    }

    public WithdrawalJobStore.Job submit(String uid, String requestId) throws Exception {
        WithdrawalJobStore.Job job = jobs.submit(uid, requestId, System.currentTimeMillis());
        sessions.forgetRevocation(uid);
        return job;
    }

    public WithdrawalJobStore.Job status(String requestId) throws Exception { return jobs.status(requestId); }

    /** A failed deletion or restarted server leaves a durable PENDING job to retry. */
    @Scheduled(initialDelayString = "${withdrawal.initial-delay-ms:10000}",
            fixedDelayString = "${withdrawal.retry-delay-ms:15000}")
    public void retryPending() {
        try {
            for (WithdrawalJobStore.Job job : jobs.pending()) process(job);
        } catch (Exception e) {
            log.error("탈퇴 작업 목록 조회 실패; 다음 주기에 재시도합니다.", e);
        }
    }

    void process(WithdrawalJobStore.Job candidate) {
        WithdrawalJobStore.Job claimed = null;
        try {
            claimed = jobs.claim(candidate, System.currentTimeMillis());
            if (claimed == null) return;
            sessions.invalidateAllForUid(claimed.uid());
            WithdrawalJobStore.Job active = claimed;
            try (var heartbeat = java.util.concurrent.Executors.newSingleThreadScheduledExecutor(
                    task -> new Thread(task, "withdrawal-lease-renewal"))) {
                heartbeat.scheduleAtFixedRate(() -> {
                    try { jobs.renew(active, System.currentTimeMillis()); }
                    catch (Exception e) { log.error("탈퇴 작업 임대 갱신 실패", e); }
                }, 30, 30, java.util.concurrent.TimeUnit.SECONDS);
                try { data.deleteUser(active.uid()); }
                finally { heartbeat.shutdownNow(); }
            }
            jobs.finish(claimed, true, System.currentTimeMillis());
            sessions.forgetRevocation(claimed.uid());
        } catch (Exception e) {
            log.error("탈퇴 데이터 삭제 실패; 저장된 작업을 재시도합니다.", e);
            if (claimed != null) {
                try { jobs.finish(claimed, false, System.currentTimeMillis()); }
                catch (Exception retryError) {
                    // A lease expires even when saving the retry state fails.
                    log.error("탈퇴 재시도 상태 저장 실패; 작업 임대 만료 후 복구합니다.", retryError);
                }
            }
        }
    }
}
