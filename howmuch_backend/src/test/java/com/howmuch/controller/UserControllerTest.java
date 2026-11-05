package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.UserProfileRequest;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.AccountWithdrawalService;
import com.howmuch.service.WithdrawalJobStore;
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
    void missingWithdrawalReceiptIsABadRequestAtTheHttpBoundary() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        AccountWithdrawalService withdrawals = mock(AccountWithdrawalService.class);
        var mvc = org.springframework.test.web.servlet.setup.MockMvcBuilders
                .standaloneSetup(new UserController(service, withdrawals))
                .setControllerAdvice(new GlobalApiExceptionHandler())
                .build();

        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .get("/api/user/withdrawal-status"))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.status().isBadRequest())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.success").value(false));

        verifyNoInteractions(service, withdrawals);
    }

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
    void acknowledgesOnlyAPersistedWithdrawalJobWithoutDeletingInTheRequest() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        AccountWithdrawalService withdrawals = mock(AccountWithdrawalService.class);
        UserController controller = new UserController(service, withdrawals);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        String id = "00000000-0000-4000-8000-000000000001";
        when(withdrawals.submit("user-1", id)).thenReturn(
                new WithdrawalJobStore.Job("user-1", id, "PENDING", 0, 0, 0, ""));

        ResponseEntity<?> response = controller.deleteUser(request, id);

        assertEquals(202, response.getStatusCode().value());
        assertEquals("PENDING", ((java.util.Map<?, ?>) response.getBody()).get("state"));
        verifyNoInteractions(service);
    }

    @Test
    void completedWithdrawalRetryReturnsOkRatherThanAccepted() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        AccountWithdrawalService withdrawals = mock(AccountWithdrawalService.class);
        UserController controller = new UserController(service, withdrawals);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        String id = "00000000-0000-4000-8000-000000000001";
        when(withdrawals.submit("user-1", id)).thenReturn(
                new WithdrawalJobStore.Job("user-1", id, "COMPLETED", 1, 0, 0, ""));
        assertEquals(200, controller.deleteUser(request, id).getStatusCode().value());
        verifyNoInteractions(service);
    }

    @Test
    void neverAcknowledgesAJobThatCouldNotBePersisted() throws Exception {
        FirebaseService service = mock(FirebaseService.class);
        AccountWithdrawalService withdrawals = mock(AccountWithdrawalService.class);
        UserController controller = new UserController(service, withdrawals);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        doThrow(new RuntimeException("Firestore unavailable"))
                .when(withdrawals).submit(org.mockito.ArgumentMatchers.eq("user-1"), any());

        ResponseEntity<?> response = controller.deleteUser(request, "00000000-0000-4000-8000-000000000001");

        assertEquals(500, response.getStatusCode().value());
        verifyNoInteractions(service);
    }

    @Test
    void missingStatusReceiptIsNotWithdrawalAcceptance() throws Exception {
        AccountWithdrawalService withdrawals = mock(AccountWithdrawalService.class);
        UserController controller = new UserController(mock(FirebaseService.class), withdrawals);
        assertEquals(404, controller.withdrawalStatus("00000000-0000-4000-8000-000000000001").getStatusCode().value());
    }
}
