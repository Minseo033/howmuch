package com.howmuch.config;

import com.howmuch.service.SessionTokenService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * 세션 토큰 인증 필터.
 * 보호 대상 경로에 대해 Authorization: Bearer <세션 토큰>을 검증하고,
 * 유효하면 request attribute "uid"에 사용자 식별자를 심어 컨트롤러에 전달합니다.
 * (기존 X-Firebase-Uid 헤더 신뢰 방식의 IDOR 취약점을 제거하기 위함)
 */
@Component
public class SessionAuthFilter extends OncePerRequestFilter {

    public static final String UID_ATTRIBUTE = "authenticatedUid";

    private final SessionTokenService sessionTokenService;

    public SessionAuthFilter(SessionTokenService sessionTokenService) {
        this.sessionTokenService = sessionTokenService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        if (requiresAuth(request)) {
            String header = request.getHeader("Authorization");
            String token = (header != null && header.startsWith("Bearer "))
                    ? header.substring(7) : null;
            String uid = sessionTokenService.verifyAndGetUid(token);

            if (uid == null) {
                response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                response.setContentType("application/json;charset=UTF-8");
                response.getWriter().write("{\"success\":false,\"message\":\"인증이 필요합니다. 다시 로그인해주세요.\"}");
                return;
            }
            request.setAttribute(UID_ATTRIBUTE, uid);
        }
        filterChain.doFilter(request, response);
    }

    /** 인증이 필요한 요청인지 판별합니다. */
    private boolean requiresAuth(HttpServletRequest request) {
        String path = request.getRequestURI();
        String method = request.getMethod();

        // CORS preflight(OPTIONS)는 크리덴셜 없이 오므로 항상 통과시킵니다.
        // 막으면 웹 브라우저가 인증 API 호출 자체를 차단합니다.
        if ("OPTIONS".equalsIgnoreCase(method)) return false;

        if (path.startsWith("/api/user/")) return true;
        if (path.startsWith("/api/report/")) return true;
        if (path.startsWith("/api/ai/")) return true;
        if (path.startsWith("/api/visits")) return true;
        // 리뷰 조회(GET)는 공개, 작성(POST)만 인증 필요
        if (path.startsWith("/api/review") && !"GET".equalsIgnoreCase(method)) return true;
        return false;
    }
}