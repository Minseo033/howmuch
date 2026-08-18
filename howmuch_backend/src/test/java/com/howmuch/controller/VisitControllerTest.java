package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.StoreCoordinates;
import com.howmuch.dto.VisitRequest;
import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.Optional;

class VisitControllerTest {

    private FirebaseService firebaseService;
    private VisitController controller;
    private MockHttpServletRequest request;

    @BeforeEach
    void setUp() {
        firebaseService = mock(FirebaseService.class);
        controller = new VisitController(firebaseService);
        request = new MockHttpServletRequest();
    }

    @Test
    void requiresAuthenticationBeforeSavingAVisit() {
        ResponseEntity<?> response = controller.createVisit(validRequest(), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(firebaseService);
    }

    @Test
    void rejectsVisitsWithoutVerifiedLocationEvidence() throws Exception {
        authenticate();
        VisitRequest requestBody = validRequest();
        when(firebaseService.findStoreCoordinates(any(), any()))
                .thenReturn(Optional.of(new StoreCoordinates(37.5675, 126.9780)));

        ResponseEntity<?> response = controller.createVisit(requestBody, request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verify(firebaseService).findStoreCoordinates(any(), any());
        verify(firebaseService, never()).saveVisit(anyString(), any(), anyLong());
    }

    @Test
    void savesOnlyLocationVerifiedVisits() throws Exception {
        authenticate();
        when(firebaseService.findStoreCoordinates(any(), any()))
                .thenReturn(Optional.of(new StoreCoordinates(37.5665, 126.9780)));
        when(firebaseService.saveVisit(anyString(), any(), anyLong())).thenReturn("visit-1");

        ResponseEntity<?> response = controller.createVisit(validRequest(), request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(firebaseService).saveVisit(anyString(), any(), anyLong());
    }

    private void authenticate() {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
    }

    private VisitRequest validRequest() {
        return VisitRequest.builder()
                .storeName("테스트 식당")
                .storeId("store-test")
                .menu("김치찌개")
                .price(8_000L)
                .verificationMethod("LOCATION")
                .verificationDistanceMeters(25.0)
                .latitude(37.5665)
                .longitude(126.9780)
                .locationAccuracyMeters(10.0)
                .build();
    }
}
