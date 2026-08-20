package com.howmuch.config;

import com.howmuch.service.SessionTokenService;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

class SessionAuthFilterReviewTest {

    private final SessionAuthFilter filter = new SessionAuthFilter(mock(SessionTokenService.class));

    @Test
    void blocksUnauthenticatedReviewCreation() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/review");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(401);
        verifyNoInteractions(chain);
    }

    @Test
    void keepsReviewLookupPublic() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/review");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(200);
        verify(chain).doFilter(request, response);
    }

    @Test
    void blocksUnauthenticatedReportDeletion() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest(
                "DELETE", "/api/report/store/report-1");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(401);
        verifyNoInteractions(chain);
    }

    @Test
    void blocksUnauthenticatedInquiryLookup() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/inquiry/my");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(401);
        verifyNoInteractions(chain);
    }

    @Test
    void blocksUnauthenticatedAccountDeletionAtTheExactUserPath() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("DELETE", "/api/user");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(401);
        verifyNoInteractions(chain);
    }
}
