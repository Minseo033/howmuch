package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 문의 등록 요청 DTO.
 * 사용자가 앱에서 문의를 작성하면 제목/내용/카테고리를 받아 Firestore inquiries 컬렉션에 저장한다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class InquiryRequest {
    /** 문의 제목 (필수, 100자 이내) */
    private String title;
    /** 문의 내용 (필수, 2000자 이내) */
    private String content;
    /** 문의 카테고리 (선택: 일반/제보/계정/기타 등) */
    private String category;
    /** Cloudinary에 먼저 업로드된 첨부 이미지 URL (최대 3개) */
    private List<String> imageUrls;
}
