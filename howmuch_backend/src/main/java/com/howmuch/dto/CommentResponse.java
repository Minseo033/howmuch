package com.howmuch.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 댓글/답글 응답 DTO.
 * 프론트(community_service.dart CommunityComment.fromJson)가 파싱하는 키와 일치:
 * id / author / content / createdAt / isMine / replyCount
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CommentResponse {
    private String id;
    private String author;
    private String content;
    private String createdAt;
    // Lombok은 boolean isMine을 "mine"으로 직렬화하므로, 프론트 명세 키(isMine)로 고정
    @JsonProperty("isMine")
    private boolean isMine;
    private int replyCount;
}
