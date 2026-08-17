package com.howmuch.service;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QuerySnapshot;
import com.google.cloud.firestore.WriteResult;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class FirebaseServiceReportDeletionTest {

    @Test
    void deletesOwnedImagesBeforeTheReportDocumentAndRemovesTheCacheEntry() throws Exception {
        Fixture fixture = new Fixture("report-1", true, "user-1", List.of("owned-url"));
        when(fixture.imageStorage.isOwnedBy("user-1", "owned-url")).thenReturn(true);
        when(fixture.imageStorage.deleteOwned("user-1", List.of("owned-url"))).thenReturn(1);
        ReflectionTestUtils.setField(fixture.service, "cachedUserStores", List.of(
                Map.of("id", "report-1"),
                Map.of("id", "report-2")));

        Map<String, Object> result = fixture.service.deleteUserReport("report-1", "user-1");

        assertThat(result).containsEntry("success", true)
                .containsEntry("id", "report-1")
                .containsEntry("deletedImages", 1)
                .containsEntry("deletedComments", 0)
                .containsEntry("deletedLikes", 0)
                .containsEntry("deletedSubscriptions", 0);
        InOrder deletionOrder = inOrder(fixture.imageStorage, fixture.document);
        deletionOrder.verify(fixture.imageStorage)
                .deleteOwned("user-1", List.of("owned-url"));
        deletionOrder.verify(fixture.document).delete();
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> cache = (List<Map<String, Object>>)
                ReflectionTestUtils.getField(fixture.service, "cachedUserStores");
        assertThat(cache).extracting(item -> item.get("id")).containsExactly("report-2");
    }

    @Test
    void rejectsDeletionWhenTheAuthenticatedUserDoesNotOwnTheReport() {
        Fixture fixture = new Fixture("report-1", true, "user-2", List.of("owned-url"));

        assertThatThrownBy(() -> fixture.service.deleteUserReport("report-1", "user-1"))
                .isInstanceOf(SecurityException.class)
                .hasMessage("본인의 제보만 삭제할 수 있습니다.");

        verify(fixture.document, never()).delete();
        verifyNoInteractions(fixture.imageStorage);
    }

    @Test
    void keepsTheReportWhenImageDeletionFailsSoTheOperationCanBeRetried() throws Exception {
        Fixture fixture = new Fixture("report-1", true, "user-1", List.of("owned-url"));
        when(fixture.imageStorage.isOwnedBy("user-1", "owned-url")).thenReturn(true);
        when(fixture.imageStorage.deleteOwned("user-1", List.of("owned-url")))
                .thenThrow(new IllegalStateException("storage unavailable"));

        assertThatThrownBy(() -> fixture.service.deleteUserReport("report-1", "user-1"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("storage unavailable");

        verify(fixture.document, never()).delete();
    }

    @Test
    void adminDeletionAlsoUsesTheOwnerStoredOnTheReport() throws Exception {
        Fixture fixture = new Fixture("report-1", true, "user-1", List.of("owned-url"));
        when(fixture.imageStorage.isOwnedBy("user-1", "owned-url")).thenReturn(true);
        when(fixture.imageStorage.deleteOwned("user-1", List.of("owned-url"))).thenReturn(1);

        Map<String, Object> result = fixture.service.deleteReportAsAdmin("report-1");

        assertThat(result).containsEntry("deletedImages", 1);
        verify(fixture.document).delete();
    }

    private static class Fixture {
        private final ReportImageStorage imageStorage = mock(ReportImageStorage.class);
        private final DocumentReference document = mock(DocumentReference.class);
        private final FirebaseService service;

        @SuppressWarnings("unchecked")
        Fixture(String reportId, boolean exists, String ownerUid, List<String> imageUrls) {
            Firestore firestore = mock(Firestore.class);
            CollectionReference collection = mock(CollectionReference.class);
            ApiFuture<DocumentSnapshot> getFuture = mock(ApiFuture.class);
            ApiFuture<WriteResult> deleteFuture = mock(ApiFuture.class);
            DocumentSnapshot snapshot = mock(DocumentSnapshot.class);

            when(firestore.collection("stores_user")).thenReturn(collection);
            when(collection.document(reportId)).thenReturn(document);
            for (String relation : List.of(
                    "comments", "feed_likes", "feed_notifications")) {
                CollectionReference relationCollection = mock(CollectionReference.class);
                Query relationQuery = mock(Query.class);
                ApiFuture<QuerySnapshot> relationFuture = mock(ApiFuture.class);
                QuerySnapshot relationSnapshot = mock(QuerySnapshot.class);
                when(firestore.collection(relation)).thenReturn(relationCollection);
                when(relationCollection.whereEqualTo("postId", reportId))
                        .thenReturn(relationQuery);
                when(relationQuery.get()).thenReturn(relationFuture);
                try {
                    when(relationFuture.get()).thenReturn(relationSnapshot);
                } catch (Exception e) {
                    throw new IllegalStateException(e);
                }
                when(relationSnapshot.getDocuments()).thenReturn(List.of());
            }
            when(document.get()).thenReturn(getFuture);
            try {
                when(getFuture.get()).thenReturn(snapshot);
                when(snapshot.exists()).thenReturn(exists);
                when(snapshot.getString("reporterId")).thenReturn(ownerUid);
                when(snapshot.get("imageUrls")).thenReturn(imageUrls);
                when(document.delete()).thenReturn(deleteFuture);
                when(deleteFuture.get()).thenReturn(mock(WriteResult.class));
            } catch (Exception e) {
                throw new IllegalStateException(e);
            }
            service = new FirebaseService(firestore, imageStorage);
        }
    }
}
