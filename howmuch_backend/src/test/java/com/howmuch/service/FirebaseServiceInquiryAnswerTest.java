package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Transaction;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FirebaseServiceInquiryAnswerTest {

    private Firestore db;
    private Transaction transaction;
    private DocumentReference inquiryRef;
    private DocumentReference notificationRef;
    private DocumentSnapshot inquiry;
    private FirebaseService service;

    @BeforeEach
    void setUp() {
        db = mock(Firestore.class);
        transaction = mock(Transaction.class);
        inquiryRef = mock(DocumentReference.class);
        notificationRef = mock(DocumentReference.class);
        inquiry = mock(DocumentSnapshot.class);
        CollectionReference inquiries = mock(CollectionReference.class);
        CollectionReference notifications = mock(CollectionReference.class);

        when(db.collection("inquiries")).thenReturn(inquiries);
        when(db.collection("notifications")).thenReturn(notifications);
        when(inquiries.document("inquiry-1")).thenReturn(inquiryRef);
        when(notifications.document("inquiry_answer_inquiry-1")).thenReturn(notificationRef);
        when(notificationRef.getId()).thenReturn("inquiry_answer_inquiry-1");
        when(transaction.get(inquiryRef)).thenReturn(ApiFutures.immediateFuture(inquiry));
        when(transaction.update(any(DocumentReference.class), anyMap())).thenReturn(transaction);
        when(transaction.set(any(DocumentReference.class), anyMap())).thenReturn(transaction);
        when(db.runTransaction(any())).thenAnswer(invocation -> {
            Transaction.Function<Object> function = invocation.getArgument(0);
            try {
                return ApiFutures.immediateFuture(function.updateCallback(transaction));
            } catch (Exception e) {
                return ApiFutures.immediateFailedFuture(e);
            }
        });
        service = new FirebaseService(db, mock(ReportImageStorage.class));
    }

    @Test
    @SuppressWarnings("unchecked")
    void storesAnswerAndUserNotificationInOneTransaction() throws Exception {
        when(inquiry.exists()).thenReturn(true);
        when(inquiry.getString("userId")).thenReturn("user-1");
        when(inquiry.getString("title")).thenReturn("앱 사용 문의");

        Map<String, Object> result = service.answerInquiry("inquiry-1", "  확인했습니다.  ");

        assertThat(result).containsEntry("status", "ANSWERED");
        ArgumentCaptor<Map<String, Object>> answerUpdate = ArgumentCaptor.forClass(Map.class);
        verify(transaction).update(eq(inquiryRef), answerUpdate.capture());
        assertThat(answerUpdate.getValue())
                .containsEntry("answer", "확인했습니다.")
                .containsEntry("status", "ANSWERED");
        ArgumentCaptor<Map<String, Object>> notification = ArgumentCaptor.forClass(Map.class);
        verify(transaction).set(eq(notificationRef), notification.capture());
        assertThat(notification.getValue())
                .containsEntry("userId", "user-1")
                .containsEntry("type", "INQUIRY_ANSWER")
                .containsEntry("relatedInquiryId", "inquiry-1");
    }

    @Test
    void missingInquiryDoesNotWriteAnswerOrNotification() {
        when(inquiry.exists()).thenReturn(false);

        assertThatThrownBy(() -> service.answerInquiry("inquiry-1", "답변"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("찾을 수 없습니다");
        verify(transaction, never()).update(any(DocumentReference.class), anyMap());
        verify(transaction, never()).set(any(DocumentReference.class), anyMap());
    }
}
