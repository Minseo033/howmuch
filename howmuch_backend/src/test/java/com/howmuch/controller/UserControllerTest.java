package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.UserProfileRequest;
import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

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
}
