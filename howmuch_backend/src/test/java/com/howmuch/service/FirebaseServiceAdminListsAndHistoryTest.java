package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** P3 정리: BE-CORE-26(가격 이력 날짜=승인일), WEB-ADM-18(가입일 없는 회원도 목록에 포함) */
class FirebaseServiceAdminListsAndHistoryTest {
    @Test
    void priceHistoryIsDatedByApprovalNotBySubmission() throws Exception {
        FirebaseService service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(service, "cachedStores", List.of(Map.of("storeId", "store_a", "storeName", "국밥집",
                "address", "서울 중구", "menu1", "국밥", "price1", "6500")));
        Map<String, Object> approved = new HashMap<>(Map.of("id", "report-1", "storeId", "store_a", "storeName", "국밥집",
                "status", "APPROVED", "resolution", "PRICE", "changeType", "rise",
                "appliedFields", Map.of("menu1", "국밥", "price1", "6500", "free1", false),
                "createdAt", "2026-09-01T00:00:00Z", "processedAt", "2026-09-05T03:00:00Z"));
        Map<String, Object> legacy = new HashMap<>(Map.of("id", "report-0", "storeId", "store_a", "storeName", "국밥집",
                "status", "APPROVED", "changeType", "drop", "menu1", "국밥", "price1", "6000",
                "createdAt", "2026-08-01T00:00:00Z"));
        ReflectionTestUtils.setField(service, "cachedUserStores", List.of(approved, legacy));

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> history = (List<Map<String, Object>>) service.getPriceHistory("store_a", "국밥").get("history");

        assertThat(history).extracting(item -> item.get("date"))
                .containsExactly("2026-09-05T03:00:00Z", "2026-08-01T00:00:00Z");
        assertThat(history.getFirst()).containsEntry("reportedAt", "2026-09-01T00:00:00Z");
    }

    @Test
    void membersWithoutASignupDateStillAppearAfterDatedMembers() throws Exception {
        Firestore db = mock(Firestore.class);
        CollectionReference users = mock(CollectionReference.class);
        Query limited = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(db.collection("users")).thenReturn(users);
        when(users.limit(5000)).thenReturn(limited);
        when(limited.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        List<QueryDocumentSnapshot> documents = List.of(
                user("old", Map.of("nickname", "옛회원", "createdAt", "2026-01-01T00:00:00Z")),
                user("goal-only", Map.of("savingsGoalAmount", 50000)),
                user("new", Map.of("nickname", "새회원", "createdAt", "2026-10-01T00:00:00Z", "secret", "x")));
        when(snapshot.getDocuments()).thenReturn(documents);
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

        List<Map<String, Object>> result = service.getAllUsers();

        assertThat(result).extracting(item -> item.get("id")).containsExactly("new", "old", "goal-only");
        assertThat(result.getFirst()).doesNotContainKey("secret");
    }

    private QueryDocumentSnapshot user(String id, Map<String, Object> data) {
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        when(document.getId()).thenReturn(id);
        when(document.getData()).thenReturn(data);
        return document;
    }
}

