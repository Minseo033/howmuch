package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.UserProfileRequest;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.SessionTokenService;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.ArgumentMatchers.any;

class UserControllerTest {

    @Test
    void rejectsInvalidProfileWithoutWritingUserData() {
        FirebaseService service = mock(FirebaseService.class);
        UserController controller = new UserController(service);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        UserProfileRequest profile = UserProfileRequest.builder()
                .nickname("  ")
                .email("not-an-email")
                .favoriteCategories(List.of("food"))
                .build();

        ResponseEntity<?> response = controller.saveUserProfile(request, profile);

        assertEquals(400, response.getStatusCode().value());
        verifyNoInteractions(service);
    }

    @Test
    void rejectsTooManyCategoriesWithoutWritingUserData() {
        FirebaseService service = mock(FirebaseService.class);
        UserController controller = new UserController(service);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        UserProfileRequest profile = UserProfileRequest.builder()
                .nickname("민서")
                .favoriteCategories(java.util.stream.IntStream.range(0, 21)
                        .mapToObj(index -> "category-" + index)
                        .toList())
                .build();

        ResponseEntity<?> response = controller.saveUserProfile(request, profile);

        assertEquals(400, response.getStatusCode().value());
        verifyNoInteractions(service);
    }

    @Test
    void stillSavesTheFirstProfileForAValidNewlyAuthenticatedUser() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        UserController controller = new UserController(service);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "kakao:rejoined-user");
        UserProfileRequest profile = UserProfileRequest.builder()
                .nickname("새 사용자")
                .email("new@example.com")
                .region("서울")
                .favoriteCategories(List.of("한식"))
                .build();
        when(service.saveUserProfile(org.mockito.ArgumentMatchers.eq("kakao:rejoined-user"), any()))
                .thenReturn(com.howmuch.dto.UserProfileResponse.builder()
                        .firebaseUid("kakao:rejoined-user").nickname("새 사용자").build());

        ResponseEntity<?> response = controller.saveUserProfile(request, profile);

        assertEquals(200, response.getStatusCode().value());
        verify(service).saveUserProfile(org.mockito.ArgumentMatchers.eq("kakao:rejoined-user"), any());
    }

    @Test
    void invalidatesTheAuthenticatedSessionAfterSuccessfulAccountDeletion() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        SessionTokenService sessions = mock(SessionTokenService.class);
        UserController controller = new UserController(service, sessions);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        when(service.deleteUser("user-1")).thenReturn(java.util.Map.of("uid", "user-1"));

        ResponseEntity<?> response = controller.deleteUser(request);

        assertEquals(200, response.getStatusCode().value());
        org.mockito.InOrder order = inOrder(sessions, service);
        order.verify(sessions).invalidateAllForUid("user-1");
        order.verify(service).deleteUser("user-1");
    }

    @Test
    void doesNotDeleteAccountWhenPersistentSessionRevocationCannotBeSaved() {
        FirebaseService service = mock(FirebaseService.class);
        SessionTokenService sessions = mock(SessionTokenService.class);
        UserController controller = new UserController(service, sessions);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        doThrow(new RuntimeException("Firestore unavailable"))
                .when(sessions).invalidateAllForUid("user-1");

        ResponseEntity<?> response = controller.deleteUser(request);

        assertEquals(500, response.getStatusCode().value());
        verify(sessions).invalidateAllForUid("user-1");
        verifyNoInteractions(service);
    }
}
