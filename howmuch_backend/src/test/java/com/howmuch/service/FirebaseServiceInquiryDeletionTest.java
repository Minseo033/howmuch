package com.howmuch.service;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.WriteResult;
import com.google.cloud.firestore.WriteBatch;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FirebaseServiceInquiryDeletionTest {

    @Test
    void deletesOwnedImagesAnswerNotificationAndInquiry() throws Exception {
        Fixture fixture = new Fixture(true);
        when(fixture.imageStorage.isOwnedBy("user-1", "owned-url")).thenReturn(true);
        when(fixture.imageStorage.deleteOwned("user-1", List.of("owned-url"))).thenReturn(1);

        Map<String, Object> result = fixture.service.deleteInquiryAsAdmin("inquiry-1");

        assertThat(result).containsEntry("success", true)
                .containsEntry("id", "inquiry-1")
                .containsEntry("deletedImages", 1);
        verify(fixture.imageStorage).deleteOwned("user-1", List.of("owned-url"));
        verify(fixture.batch).delete(fixture.notificationDocument);
        verify(fixture.batch).delete(fixture.inquiryDocument);
        verify(fixture.batch).commit();
    }

    @Test
    void keepsStorageAndDocumentsUntouchedWhenInquiryDoesNotExist() throws Exception {
        Fixture fixture = new Fixture(false);

        assertThatThrownBy(() -> fixture.service.deleteInquiryAsAdmin("inquiry-1"))
                .isInstanceOf(NoSuchElementException.class)
                .hasMessage("문의를 찾을 수 없습니다.");

        verify(fixture.batch, never()).commit();
        verify(fixture.imageStorage, never()).deleteOwned("user-1", List.of("owned-url"));
    }

    @Test
    void keepsInquiryWhenAttachedImageOwnerIsMissing() {
        Fixture fixture = new Fixture(true, null, List.of("owned-url"));

        assertThatThrownBy(() -> fixture.service.deleteInquiryAsAdmin("inquiry-1"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("첨부 이미지 소유자 정보를 확인할 수 없습니다.");

        verify(fixture.batch, never()).commit();
    }

    private static class Fixture {
        private final ReportImageStorage imageStorage = mock(ReportImageStorage.class);
        private final DocumentReference inquiryDocument = mock(DocumentReference.class);
        private final DocumentReference notificationDocument = mock(DocumentReference.class);
        private final WriteBatch batch = mock(WriteBatch.class);
        private final FirebaseService service;

        @SuppressWarnings("unchecked")
        Fixture(boolean exists) {
            this(exists, "user-1", List.of("owned-url"));
        }

        @SuppressWarnings("unchecked")
        Fixture(boolean exists, String ownerUid, List<String> imageUrls) {
            Firestore firestore = mock(Firestore.class);
            CollectionReference inquiries = mock(CollectionReference.class);
            CollectionReference notifications = mock(CollectionReference.class);
            ApiFuture<DocumentSnapshot> getFuture = mock(ApiFuture.class);
            ApiFuture<List<WriteResult>> batchFuture = mock(ApiFuture.class);
            DocumentSnapshot snapshot = mock(DocumentSnapshot.class);

            when(firestore.collection("inquiries")).thenReturn(inquiries);
            when(firestore.collection("notifications")).thenReturn(notifications);
            when(inquiries.document("inquiry-1")).thenReturn(inquiryDocument);
            when(notifications.document("inquiry_answer_inquiry-1"))
                    .thenReturn(notificationDocument);
            when(inquiryDocument.get()).thenReturn(getFuture);
            when(firestore.batch()).thenReturn(batch);
            when(batch.delete(notificationDocument)).thenReturn(batch);
            when(batch.delete(inquiryDocument)).thenReturn(batch);
            when(batch.commit()).thenReturn(batchFuture);
            try {
                when(getFuture.get()).thenReturn(snapshot);
                when(snapshot.exists()).thenReturn(exists);
                when(snapshot.getString("userId")).thenReturn(ownerUid);
                when(snapshot.get("imageUrls")).thenReturn(imageUrls);
                when(batchFuture.get()).thenReturn(List.of(
                        mock(WriteResult.class),
                        mock(WriteResult.class)));
            } catch (Exception e) {
                throw new IllegalStateException(e);
            }
            service = new FirebaseService(firestore, imageStorage);
        }
    }
}
