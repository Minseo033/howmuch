package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 댓글/답글 작성 요청 DTO
 * POST /api/community/feed/{postId}/comments
 * POST /api/community/comments/{commentId}/replies
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CommentRequest {
    private String content; // 댓글 내용 (필수)
}
