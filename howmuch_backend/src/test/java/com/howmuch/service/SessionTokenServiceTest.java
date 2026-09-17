package com.howmuch.service;

import org.junit.jupiter.api.Test;
import com.howmuch.config.SessionAuthFilter;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
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

        assertThatThrownBy(() -> checkingInstance.verifyAndGetUid(token))
                .isInstanceOf(SessionRevocationStore.UnavailableException.class);
    }

    @Test
    void outageReturns503WithoutAuthorizingAndTheSameTokenWorksAfterRecovery() throws Exception {
        SessionRevocationStore store = mock(SessionRevocationStore.class);
        String token = new SessionTokenService("test-secret", 1, true).createToken("user-1");
        when(store.getRevokedAfter("user-1"))
                .thenThrow(new SessionRevocationStore.UnavailableException("timeout", null))
                .thenReturn(Long.MIN_VALUE);
        SessionAuthFilter filter = new SessionAuthFilter(
                new SessionTokenService("test-secret", 1, true, store));
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/user/profile");
        request.addHeader("Authorization", "Bearer " + token);
        MockHttpServletResponse failed = new MockHttpServletResponse();
        MockFilterChain blockedChain = new MockFilterChain();

        filter.doFilter(request, failed, blockedChain);

        assertThat(failed.getStatus()).isEqualTo(503);
        assertThat(failed.getHeader("Retry-After")).isEqualTo("5");
        assertThat(blockedChain.getRequest()).isNull();
        assertThat(request.getAttribute(SessionAuthFilter.UID_ATTRIBUTE)).isNull();

        MockHttpServletResponse recovered = new MockHttpServletResponse();
        MockFilterChain recoveredChain = new MockFilterChain();
        filter.doFilter(request, recovered, recoveredChain);
        assertThat(recovered.getStatus()).isEqualTo(200);
        assertThat(request.getAttribute(SessionAuthFilter.UID_ATTRIBUTE)).isEqualTo("user-1");
        assertThat(recoveredChain.getRequest()).isSameAs(request);
    }
}
