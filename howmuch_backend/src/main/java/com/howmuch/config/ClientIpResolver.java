package com.howmuch.config;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.net.InetAddress;
import java.util.ArrayList;
import java.util.List;

/**
 * Resolves a client address only when the direct peer is a configured trusted proxy.
 * X-Forwarded-For is otherwise attacker-controlled and must not be used for rate limits.
 */
@Component
public class ClientIpResolver {

    private final List<Cidr> trustedProxies;
    private final boolean trustRenderCfConnectingIp;

    @Autowired
    public ClientIpResolver(
            @Value("${proxy.trusted-cidrs:127.0.0.1/32,::1/128}") String trustedProxyCidrs,
            @Value("${proxy.trust-render-cf-connecting-ip:false}") boolean trustRenderCfConnectingIp) {
        this.trustedProxies = parseTrustedCidrs(trustedProxyCidrs);
        this.trustRenderCfConnectingIp = trustRenderCfConnectingIp;
    }

    public ClientIpResolver(String trustedProxyCidrs) {
        this(trustedProxyCidrs, false);
    }

    public String resolve(HttpServletRequest request) {
        // Render's public ingress replaces this header with Cloudflare's client address.
        // This branch is opt-in and is enabled only by the Render deployment manifest; do not
        // enable it for a generic reverse proxy, where the header can be client supplied.
        if (trustRenderCfConnectingIp) {
            String cloudflareClient = validAddress(request.getHeader("CF-Connecting-IP"));
            if (cloudflareClient != null) return cloudflareClient;
        }
        String remoteAddress = validAddress(request.getRemoteAddr());
        if (remoteAddress == null || !isTrusted(remoteAddress)) {
            return remoteAddress == null ? "unknown" : remoteAddress;
        }

        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded == null || forwarded.isBlank()) return remoteAddress;
        String[] chain = forwarded.split(",");
        for (int index = chain.length - 1; index >= 0; index--) {
            String address = validAddress(chain[index]);
            if (address != null && !isTrusted(address)) return address;
        }
        return remoteAddress;
    }

    private static List<Cidr> parseTrustedCidrs(String rawCidrs) {
        List<Cidr> parsed = new ArrayList<>();
        if (rawCidrs == null || rawCidrs.isBlank()) return List.of();
        for (String raw : rawCidrs.split(",")) {
            try {
                String[] parts = raw.trim().split("/", 2);
                InetAddress network = InetAddress.getByName(parts[0]);
                int prefix = parts.length == 2 ? Integer.parseInt(parts[1]) : network.getAddress().length * 8;
                if (prefix >= 0 && prefix <= network.getAddress().length * 8) {
                    parsed.add(new Cidr(network.getAddress(), prefix));
                }
            } catch (Exception ignored) {
                // Invalid configuration entries are deliberately never trusted.
            }
        }
        return List.copyOf(parsed);
    }

    private boolean isTrusted(String address) {
        try {
            byte[] candidate = InetAddress.getByName(address).getAddress();
            return trustedProxies.stream().anyMatch(cidr -> cidr.contains(candidate));
        } catch (Exception ignored) {
            return false;
        }
    }

    private static String validAddress(String raw) {
        if (raw == null || raw.isBlank() || raw.length() > 64) return null;
        try {
            String candidate = raw.trim();
            // Headers must be numeric literals. Passing hostnames to getByName would turn a
            // user-controlled rate-limit header into a DNS lookup path (and accept aliases).
            if (!candidate.matches("[0-9A-Fa-f:.]+")) return null;
            return InetAddress.getByName(candidate).getHostAddress();
        } catch (Exception ignored) {
            return null;
        }
    }

    private record Cidr(byte[] network, int prefixLength) {
        boolean contains(byte[] candidate) {
            if (candidate.length != network.length) return false;
            int fullBytes = prefixLength / 8;
            int remainingBits = prefixLength % 8;
            for (int index = 0; index < fullBytes; index++) {
                if (candidate[index] != network[index]) return false;
            }
            if (remainingBits == 0) return true;
            int mask = 0xFF << (8 - remainingBits);
            return (candidate[fullBytes] & mask) == (network[fullBytes] & mask);
        }
    }
}
