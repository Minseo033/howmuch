package com.howmuch.service;

import org.junit.jupiter.api.Test;
import com.howmuch.config.SessionAuthFilter;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
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
        when(store.getRevocation("user-1")).thenAnswer(
                invocation -> new SessionRevocationStore.Revocation(cutoff.get(), Set.of()));
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
        when(store.getRevocation("user-1"))
                .thenThrow(new SessionRevocationStore.UnavailableException("unavailable", null));
        SessionTokenService checkingInstance = new SessionTokenService("test-secret", 1, true, store);

        assertThatThrownBy(() -> checkingInstance.verifyAndGetUid(token))
                .isInstanceOf(SessionRevocationStore.UnavailableException.class);
    }

    @Test
    void outageReturns503WithoutAuthorizingAndTheSameTokenWorksAfterRecovery() throws Exception {
        SessionRevocationStore store = mock(SessionRevocationStore.class);
        String token = new SessionTokenService("test-secret", 1, true).createToken("user-1");
        when(store.getRevocation("user-1"))
                .thenThrow(new SessionRevocationStore.UnavailableException("timeout", null))
                .thenReturn(SessionRevocationStore.Revocation.NONE);
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

    @Test
    void revocationCutoffIsCachedBrieflyInsteadOfReadOnEveryRequest() {
        SessionRevocationStore store = mock(SessionRevocationStore.class);
        when(store.getRevocation("user-1")).thenReturn(SessionRevocationStore.Revocation.NONE);
        AtomicLong now = new AtomicLong(1_000_000L);
        SessionTokenService service = new SessionTokenService("test-secret", 1, true, store, now::get);
        String token = service.createToken("user-1");

        assertThat(service.verifyAndGetUid(token)).isEqualTo("user-1");
        assertThat(service.verifyAndGetUid(token)).isEqualTo("user-1");
        verify(store, times(1)).getRevocation("user-1");

        now.addAndGet(SessionTokenService.REVOCATION_CACHE_TTL_MILLIS + 1);
        assertThat(service.verifyAndGetUid(token)).isEqualTo("user-1");
        verify(store, times(2)).getRevocation("user-1");
    }

    @Test
    void revokingOnThisInstanceRejectsOldTokensImmediatelyDespiteTheCache() {
        SessionRevocationStore store = mock(SessionRevocationStore.class);
        AtomicLong persisted = new AtomicLong(Long.MIN_VALUE);
        when(store.getRevocation("user-1")).thenAnswer(
                invocation -> new SessionRevocationStore.Revocation(persisted.get(), Set.of()));
        when(store.revokeAt(org.mockito.ArgumentMatchers.eq("user-1"),
                org.mockito.ArgumentMatchers.anyLong())).thenAnswer(invocation -> {
            persisted.accumulateAndGet(invocation.getArgument(1), Math::max);
            return persisted.get();
        });
        AtomicLong now = new AtomicLong(5_000_000L);
        SessionTokenService service = new SessionTokenService("test-secret", 1, true, store, now::get);
        String oldToken = service.createToken("user-1");
        assertThat(service.verifyAndGetUid(oldToken)).isEqualTo("user-1");

        now.incrementAndGet();
        service.invalidateAllForUid("user-1");

        assertThat(service.verifyAndGetUid(oldToken)).isNull();
        now.incrementAndGet();
        assertThat(service.verifyAndGetUid(service.createToken("user-1"))).isEqualTo("user-1");
    }

    @Test
    void outageDoesNotTakeDownPublicReadsThatCarryAToken() throws Exception {
        SessionRevocationStore store = mock(SessionRevocationStore.class);
        String token = new SessionTokenService("test-secret", 1, true).createToken("user-1");
        when(store.getRevocation("user-1"))
                .thenThrow(new SessionRevocationStore.UnavailableException("quota", null));
        SessionAuthFilter filter = new SessionAuthFilter(
                new SessionTokenService("test-secret", 1, true, store));

        MockHttpServletRequest publicRead = new MockHttpServletRequest("GET", "/api/stores/bounds");
        publicRead.addHeader("Authorization", "Bearer " + token);
        MockHttpServletResponse publicResponse = new MockHttpServletResponse();
        MockFilterChain publicChain = new MockFilterChain();
        filter.doFilter(publicRead, publicResponse, publicChain);

        assertThat(publicResponse.getStatus()).isEqualTo(200);
        assertThat(publicChain.getRequest()).isSameAs(publicRead);
        assertThat(publicRead.getAttribute(SessionAuthFilter.UID_ATTRIBUTE)).isNull();

        MockHttpServletRequest protectedWrite = new MockHttpServletRequest("POST", "/api/review");
        protectedWrite.addHeader("Authorization", "Bearer " + token);
        MockHttpServletResponse protectedResponse = new MockHttpServletResponse();
        MockFilterChain protectedChain = new MockFilterChain();
        filter.doFilter(protectedWrite, protectedResponse, protectedChain);

        assertThat(protectedResponse.getStatus()).isEqualTo(503);
        assertThat(protectedChain.getRequest()).isNull();
    }
    @Test
    void loggingOutOneDeviceRejectsOnlyThatDevicesToken() {
        SessionRevocationStore store = mock(SessionRevocationStore.class);
        AtomicReference<SessionRevocationStore.Revocation> persisted =
                new AtomicReference<>(SessionRevocationStore.Revocation.NONE);
        when(store.getRevocation("user-1")).thenAnswer(invocation -> persisted.get());
        when(store.revokeToken(org.mockito.ArgumentMatchers.eq("user-1"),
                org.mockito.ArgumentMatchers.anyLong(), org.mockito.ArgumentMatchers.anyLong()))
                .thenAnswer(invocation -> {
                    Set<Long> tokens = new HashSet<>(persisted.get().revokedIssuedAt());
                    tokens.add(invocation.getArgument(1));
                    persisted.set(new SessionRevocationStore.Revocation(persisted.get().revokedAfter(), tokens));
                    return persisted.get();
                });
        AtomicLong now = new AtomicLong(10_000_000L);
        SessionTokenService service = new SessionTokenService("test-secret", 1, true, store, now::get);
        String phone = service.createToken("user-1");
        now.addAndGet(5);
        String laptop = service.createToken("user-1");
        assertThat(service.verifyAndGetUid(phone)).isEqualTo("user-1");

        assertThat(service.revokeToken(phone)).isTrue();

        assertThat(service.verifyAndGetUid(phone)).isNull();
        assertThat(service.verifyAndGetUid(laptop)).isEqualTo("user-1");
        SessionTokenService anotherInstance = new SessionTokenService("test-secret", 1, true, store, now::get);
        assertThat(anotherInstance.verifyAndGetUid(phone)).isNull();
        assertThat(anotherInstance.verifyAndGetUid(laptop)).isEqualTo("user-1");
        assertThat(service.revokeToken("forged.token")).isFalse();
    }
}
