package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class GlobalApiExceptionHandlerTest {

    private FirebaseService firebaseService;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        firebaseService = mock(FirebaseService.class);
        mockMvc = MockMvcBuilders
                .standaloneSetup(new NotificationController(firebaseService))
                .setControllerAdvice(new GlobalApiExceptionHandler())
                .build();
    }

    @Test
    void returnsAStableJsonErrorForMalformedJson() throws Exception {
        mockMvc.perform(post("/api/notifications/devices")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{broken"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("요청 형식이 올바르지 않습니다."));

        verifyNoInteractions(firebaseService);
    }

    @Test
    void returnsAStableJsonErrorForInvalidValidatedFields() throws Exception {
        mockMvc.perform(post("/api/notifications/devices")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"token\",\"platform\":\"windows\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("요청값 형식이 올바르지 않습니다."));

        verifyNoInteractions(firebaseService);
    }
}
