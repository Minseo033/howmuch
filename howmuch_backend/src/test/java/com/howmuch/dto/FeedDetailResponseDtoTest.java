package com.howmuch.dto;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class FeedDetailResponseDtoTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void serializesAuthenticatedInteractionStateWithFrontendKeys() throws Exception {
        FeedDetailResponseDto response = FeedDetailResponseDto.builder()
                .id("post-1")
                .likedByMe(true)
                .notificationEnabled(true)
                .build();

        JsonNode json = objectMapper.readTree(objectMapper.writeValueAsString(response));

        assertThat(json.get("likedByMe").asBoolean()).isTrue();
        assertThat(json.get("notificationEnabled").asBoolean()).isTrue();
        assertThat(json.has("likeByMe")).isFalse();
    }
}
