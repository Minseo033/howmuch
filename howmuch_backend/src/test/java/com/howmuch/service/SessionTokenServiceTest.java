package com.howmuch.service;

import org.junit.jupiter.api.Test;

import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class SessionTokenServiceTest {

    @Test
    void supportsRealKakaoUidsContainingAColon() {
        SessionTokenService service = new SessionTokenService("test-secret", 1, true);

        String token = service.createToken("kakao:1234567890");

        assertThat(service.verifyAndGetUid(token)).isEqualTo("kakao:1234567890");
    }

    @Test
    void immediatelyInvalidatesSessionsForDeletedAccounts() {
        SessionTokenService service = new SessionTokenService("test-secret", 1, true);
        String oldToken = service.createToken("user-1");

        service.invalidateAllForUid("user-1");

        assertThat(service.verifyAndGetUid(oldToken)).isNull();
        assertThat(service.verifyAndGetUid(service.createToken("user-1"))).isEqualTo("user-1");
    }

    @Test
    void rejectsLegacyTwoPartTokensInsteadOfTreatingThemAsUnrevocable() {
        SessionTokenService service = new SessionTokenService("test-secret", 1, true);

        assertThat(service.verifyAndGetUid("dXNlci0xOjE3MDAwMDAwMDAwMDA.sig")).isNull();
    }

    @Test
    void aPersistedCutoffRejectsAnOldTokenOnAnotherServiceInstance() {
        SessionRevocationStore store = mock(SessionRevocationStore.class);
        AtomicLong cutoff = new AtomicLong(Long.MIN_VALUE);
        when(store.getRevokedAfter("user-1")).thenAnswer(invocation -> cutoff.get());
        when(store.revokeAt(org.mockito.ArgumentMatchers.eq("user-1"),
                org.mockito.ArgumentMatchers.anyLong())).thenAnswer(invocation -> {
            cutoff.accumulateAndGet(invocation.getArgument(1), Math::max);
            return cutoff.get();
        });
        SessionTokenService issuingInstance = new SessionTokenService("test-secret", 1, true, store);
        String oldToken = issuingInstance.createToken("user-1");

        issuingInstance.invalidateAllForUid("user-1");
        SessionTokenService anotherInstance = new SessionTokenService("test-secret", 1, true, store);

        assertThat(anotherInstance.verifyAndGetUid(oldToken)).isNull();
        assertThat(anotherInstance.createToken("user-1")).isNotEqualTo(oldToken);
        assertThat(anotherInstance.verifyAndGetUid(anotherInstance.createToken("user-1")))
                .isEqualTo("user-1");
    }

    @Test
    void failsClosedWhenTheSharedRevocationStoreIsUnavailable() {
        SessionRevocationStore store = mock(SessionRevocationStore.class);
        SessionTokenService issuingInstance = new SessionTokenService("test-secret", 1, true);
        String token = issuingInstance.createToken("user-1");
        when(store.getRevokedAfter("user-1"))
                .thenThrow(new SessionRevocationStore.UnavailableException("unavailable", null));
        SessionTokenService checkingInstance = new SessionTokenService("test-secret", 1, true, store);

        assertThat(checkingInstance.verifyAndGetUid(token)).isNull();
    }
}
