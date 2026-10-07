package com.howmuch.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.howmuch.dto.SavingsHistoryResponse;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** QA 2026-10-07 #41: 절약 내역은 지도·매장 상세와 같은 매장 출처를 보내 앱이 매장을 다시 조회하지 않게 합니다. */
class FirebaseServiceSavingsHistoryTest {
    @Test
    void savingsHistorySendsTheMapStoreSourceAndStillOnlyContractFields() throws Exception {
        Firestore db = mock(Firestore.class);
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(service, "cachedStores", List.of(
                Map.of("storeId", "store_gov", "storeName", "흥부순대국", "address", "서울 중구")));
        ReflectionTestUtils.setField(service, "cachedUserStores", List.of(
                Map.of("storeId", "store_hak", "storeName", "동양미래대학교 학식당", "address", "서울 구로구",
                        "status", "APPROVED")));
        CollectionReference visits = mock(CollectionReference.class);
        Query query = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(db.collection("visits")).thenReturn(visits);
        when(visits.whereEqualTo("userId", "user-1")).thenReturn(query);
        when(query.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        List<QueryDocumentSnapshot> documents = List.of(
                visit("gov", "store_gov", "흥부순대국", true),
                visit("user", "store_hak", "동양미래대학교 학식당", false),
                // 매장 ID 없이 저장된 옛 방문은 방문 저장 때처럼 매장명으로 찾습니다.
                visit("legacy", null, "동양미래대학교 학식당", false),
                // 지금 목록에 없는 매장은 출처를 비워 앱이 저장된 isGov로 판단하게 합니다.
                visit("gone", "removed-store", "없어진 매장", true));
        when(snapshot.getDocuments()).thenReturn(documents);

        Map<String, SavingsHistoryResponse> history = new HashMap<>();
        service.getSavingsHistory("user-1").forEach(item -> history.put(item.getId(), item));

        assertThat(history.get("gov").getStoreSource()).isEqualTo("GOV");
        assertThat(history.get("user").getStoreSource()).isEqualTo("USER");
        assertThat(history.get("legacy").getStoreSource()).isEqualTo("USER");
        assertThat(history.get("gone").getStoreSource()).isNull();
        assertThat(history.get("gone").getIsGov()).isTrue();
        // 앱이 읽는 JSON 이름 그대로 나가고, 방문 문서의 회원·인증·영수증 정보는 계속 빠집니다.
        @SuppressWarnings("unchecked")
        Map<String, Object> json = new ObjectMapper().convertValue(history.get("user"), Map.class);
        assertThat(json).containsEntry("storeSource", "USER").containsEntry("isGov", false)
                .containsOnlyKeys("id", "storeId", "storeName", "category", "visitedAt", "date", "menu",
                        "price", "savedAmount", "isGov", "isFree", "storeSource");
    }

    private QueryDocumentSnapshot visit(String id, String storeId, String storeName, boolean isGov) {
        Map<String, Object> data = new HashMap<>();
        data.put("userId", "user-1");
        if (storeId != null) data.put("storeId", storeId);
        data.put("storeName", storeName);
        data.put("industry", "한식");
        data.put("menu", "라면");
        data.put("price", 4000L);
        data.put("savedAmount", 2000L);
        data.put("isGov", isGov);
        data.put("isFree", false);
        data.put("visitedAt", "2026-10-06T03:00:00Z");
        data.put("receiptId", "receipt-" + id);
        data.put("verificationMethod", "RECEIPT");
        data.put("verificationDistanceMeters", 12.5);
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        when(document.getId()).thenReturn(id);
        when(document.getData()).thenReturn(data);
        return document;
    }
}
