package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.WriteResult;
import com.howmuch.dto.InquiryRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FirebaseServiceInquiryCreationTest {

    private Firestore db;
    private ReportImageStorage imageStorage;
    private DocumentReference inquiryRef;
    private FirebaseService service;

    @BeforeEach
    void setUp() {
        db = mock(Firestore.class);
        imageStorage = mock(ReportImageStorage.class);
        CollectionReference inquiries = mock(CollectionReference.class);
        inquiryRef = mock(DocumentReference.class);
        when(db.collection("inquiries")).thenReturn(inquiries);
        when(inquiries.document()).thenReturn(inquiryRef);
        when(inquiryRef.getId()).thenReturn("inquiry-1");
        when(inquiryRef.set(anyMap()))
                .thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));
        service = new FirebaseService(db, imageStorage);
    }

    @Test
    @SuppressWarnings("unchecked")
    void storesOnlyAnOwnedInquiryAttachment() throws Exception {
        String imageUrl = "https://res.cloudinary.com/demo/image/upload/howmuch/report-images/user-1/photo.jpg";
        when(imageStorage.isOwnedBy("user-1", imageUrl)).thenReturn(true);
        InquiryRequest request = InquiryRequest.builder()
                .title(" 사진 문의 ")
                .content(" 첨부를 확인해주세요. ")
                .category(" 기타 ")
                .imageUrls(List.of(imageUrl))
                .build();

        Map<String, Object> result = service.createInquiry("user-1", request);

        assertThat(result).containsEntry("id", "inquiry-1");
        ArgumentCaptor<Map<String, Object>> saved = ArgumentCaptor.forClass(Map.class);
        verify(inquiryRef).set(saved.capture());
        assertThat(saved.getValue())
                .containsEntry("title", "사진 문의")
                .containsEntry("content", "첨부를 확인해주세요.")
                .containsEntry("imageUrls", List.of(imageUrl));
    }

    @Test
    void rejectsAnExternalImageUrlBeforeWritingInquiry() {
        String imageUrl = "https://example.com/not-owned.jpg";
        InquiryRequest request = InquiryRequest.builder()
                .title("문의")
                .content("내용")
                .imageUrls(List.of(imageUrl))
                .build();

        assertThatThrownBy(() -> service.createInquiry("user-1", request))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("이미지 URL");
        verify(inquiryRef, never()).set(anyMap());
    }
}
