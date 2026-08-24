package com.howmuch.controller;

import com.howmuch.service.KakaoLocalService;
import com.howmuch.service.SimpleRateLimiter;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

class LocationControllerTest {

    @Test
    void rejectsInvalidPublicLocationRequestsBeforeCallingKakao() {
        KakaoLocalService kakao = mock(KakaoLocalService.class);
        LocationController controller = new LocationController(kakao, mock(SimpleRateLimiter.class));
        MockHttpServletRequest request = new MockHttpServletRequest();

        assertThat(controller.searchAddresses("a", request).getStatusCode().value()).isEqualTo(400);
        assertThat(controller.reverseGeocode(Double.NaN, 127.0, request).getStatusCode().value()).isEqualTo(400);
        verifyNoInteractions(kakao);
    }
}
