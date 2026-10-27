package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReviewRequest {
    private String storeId;
    private String storeName;
    /** 하위 호환용 입력. 서버는 이 값을 저장·표시하지 않고 회원 정보로 작성자명을 정합니다. */
    private String authorName;
    private String menu;
    private Integer price;
    private String content;
    private int stars;
}
