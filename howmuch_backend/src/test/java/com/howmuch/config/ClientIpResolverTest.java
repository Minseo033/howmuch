package com.howmuch.config;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThat;

class ClientIpResolverTest {

    @Test
    void ignoresForwardedHeadersFromAnUntrustedPeer() {
        ClientIpResolver resolver = new ClientIpResolver("10.0.0.0/8");
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("203.0.113.10");
        request.addHeader("X-Forwarded-For", "198.51.100.20");

        assertThat(resolver.resolve(request)).isEqualTo("203.0.113.10");
    }

    @Test
    void selectsTheFirstUntrustedAddressBehindTrustedProxies() {
        ClientIpResolver resolver = new ClientIpResolver("10.0.0.0/8");
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("10.0.0.2");
        request.addHeader("X-Forwarded-For", "198.51.100.20, 10.0.0.1");

        assertThat(resolver.resolve(request)).isEqualTo("198.51.100.20");
    }

    @Test
    void trustsRenderNormalizedCloudflareAddressOnlyWhenExplicitlyEnabled() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("203.0.113.10");
        request.addHeader("CF-Connecting-IP", "198.51.100.20");
        request.addHeader("X-Forwarded-For", "attacker-controlled");

        assertThat(new ClientIpResolver("10.0.0.0/8", true).resolve(request))
                .isEqualTo("198.51.100.20");
        assertThat(new ClientIpResolver("10.0.0.0/8", false).resolve(request))
                .isEqualTo("203.0.113.10");
    }

    @Test
    void ignoresMalformedRenderCloudflareAddress() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("203.0.113.10");
        request.addHeader("CF-Connecting-IP", "not-an-ip");

        assertThat(new ClientIpResolver("10.0.0.0/8", true).resolve(request))
                .isEqualTo("203.0.113.10");
    }

    @Test
    void rejectsHostnamesInsteadOfResolvingHeaderControlledDns() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("203.0.113.10");
        request.addHeader("CF-Connecting-IP", "localhost");

        assertThat(new ClientIpResolver("10.0.0.0/8", true).resolve(request))
                .isEqualTo("203.0.113.10");
    }
}
