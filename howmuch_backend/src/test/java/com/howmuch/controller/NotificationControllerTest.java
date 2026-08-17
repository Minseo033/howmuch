package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.DeviceTokenRequest;
import com.howmuch.dto.PriceAlertSubscriptionDto;
import com.howmuch.dto.PriceAlertSubscriptionRequest;
import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class NotificationControllerTest {

    @Test
    void registersTheAuthenticatedUsersDeviceToken() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        NotificationController controller = new NotificationController(service);
        MockHttpServletRequest request = authenticatedRequest();

        ResponseEntity<?> response = controller.registerDevice(
                new DeviceTokenRequest("token-1", "android"), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(service).registerDeviceToken("user-1", "token-1", "android");
    }

    @Test
    void doesNotRegisterAnUnauthenticatedDeviceToken() {
        FirebaseService service = mock(FirebaseService.class);
        NotificationController controller = new NotificationController(service);

        ResponseEntity<?> response = controller.registerDevice(
                new DeviceTokenRequest("token-1", "android"), new MockHttpServletRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(service);
    }

    @Test
    void unregistersOnlyTheAuthenticatedUsersCurrentDevice() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        NotificationController controller = new NotificationController(service);

        ResponseEntity<?> response = controller.unregisterDevice(
                new DeviceTokenRequest("token-1", "ios"), authenticatedRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(service).unregisterDeviceToken("user-1", "token-1");
    }

    @Test
    void returnsAuthenticatedUsersPriceAlertSubscriptions() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        NotificationController controller = new NotificationController(service);
        when(service.getPriceAlertSubscriptions("user-1")).thenReturn(List.of(
                PriceAlertSubscriptionDto.builder()
                        .storeId("store-1")
                        .storeName("실제 찜 매장")
                        .menuName("김치찌개")
                        .enabled(true)
                        .build()));

        ResponseEntity<?> response = controller.getPriceAlertSubscriptions(authenticatedRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(List.of(
                PriceAlertSubscriptionDto.builder()
                        .storeId("store-1")
                        .storeName("실제 찜 매장")
                        .menuName("김치찌개")
                        .enabled(true)
                        .build()));
        verify(service).getPriceAlertSubscriptions("user-1");
    }

    @Test
    void savesOnlyAuthenticatedUsersPriceAlertSubscription() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        NotificationController controller = new NotificationController(service);
        PriceAlertSubscriptionRequest request = new PriceAlertSubscriptionRequest(
                "store-1", false, true, true, false);
        when(service.savePriceAlertSubscription("user-1", request)).thenReturn(
                PriceAlertSubscriptionDto.builder()
                        .storeId("store-1")
                        .storeName("실제 찜 매장")
                        .menuName("김치찌개")
                        .enabled(false)
                        .build());

        ResponseEntity<?> response = controller.savePriceAlertSubscription(request, authenticatedRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(service).savePriceAlertSubscription("user-1", request);
    }

    @Test
    void doesNotExposePriceAlertSubscriptionsWithoutAuthentication() {
        FirebaseService service = mock(FirebaseService.class);
        NotificationController controller = new NotificationController(service);

        ResponseEntity<?> response = controller.getPriceAlertSubscriptions(new MockHttpServletRequest());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(service);
    }

    private MockHttpServletRequest authenticatedRequest() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        return request;
    }
}
