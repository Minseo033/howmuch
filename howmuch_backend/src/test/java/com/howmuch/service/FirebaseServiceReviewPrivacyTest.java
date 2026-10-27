package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.howmuch.dto.ReviewRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** 계약 C1: 공개 리뷰 응답은 화이트리스트이고, 작성자명은 서버가 회원 정보로 정합니다. */
class FirebaseServiceReviewPrivacyTest {
    private static final List<String> PUBLIC_FIELDS = List.of("id", "storeId", "storeName", "storeSource",
            "authorName", "menu", "price", "content", "stars", "likes", "ownerReply", "createdAt");

    private final Firestore db = mock(Firestore.class);
    private final FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));
    private final CollectionReference reviews = mock(CollectionReference.class);
    private final CollectionReference users = mock(CollectionReference.class);

    @BeforeEach
    void setUp() {
        when(db.collection("reviews")).thenReturn(reviews);
        when(db.collection("users")).thenReturn(users);
        ReflectionTestUtils.setField(service, "cachedStores", List.of(
                Map.of("storeId", "store_a", "storeName", "경남식당", "address", "서울 중구"),
                Map.of("storeId", "store_closed", "storeName", "폐업식당", "address", "부산", "isClosed", true)));
        // 고유한 매장명은 옛 이름 기준 리뷰도 함께 조회합니다.
        query("storeId", "경남식당", List.of());
        query("storeId", "폐업식당", List.of());
    }

    @Test
    void publicReviewsExposeOnlyContractFieldsWithServerResolvedAuthorNames() throws Exception {
        user("kakao:111", Map.of("nickname", "진짜닉네임"));
        user("kakao:222", Map.of("nickname", "숨긴닉네임", "nicknamePublic", false));
        missingUser("kakao:333");
        user("kakao:444", Map.of("nickname", "   ", "nicknamePublic", true));
        query("storeId", "store_a", List.of(
                review("r1", "kakao:111", "운영자", "2026-10-04T00:00:00Z"),
                review("r2", "kakao:222", "숨긴닉네임", "2026-10-03T00:00:00Z"),
                review("r3", "kakao:333", "아무개", "2026-10-02T00:00:00Z"),
                review("r4", "kakao:444", "빈닉네임", "2026-10-01T00:00:00Z"),
                review("r5", null, "옛날리뷰", "2026-09-30T00:00:00Z")));

        List<Map<String, Object>> result = service.getReviews("store_a");

        assertThat(result).extracting(row -> row.get("id"))
                .containsExactly("r1", "r2", "r3", "r4", "r5");
        assertThat(result).allSatisfy(row -> {
            assertThat(row.keySet()).containsExactlyInAnyOrderElementsOf(PUBLIC_FIELDS);
            assertThat(row.values()).doesNotContain("kakao:111", "kakao:222", "kakao:333", "서울 중구", "내부값");
            assertThat(row).containsEntry("storeId", "store_a").containsEntry("storeSource", "GOV");
        });
        assertThat(result).extracting(row -> row.get("authorName"))
                .containsExactly("진짜닉네임", "익명", "사용자", "사용자", "사용자");
        assertThat(result.getFirst()).containsEntry("menu", "백반").containsEntry("price", 7000)
                .containsEntry("stars", 4).containsEntry("likes", 0).containsEntry("content", "맛있어요");
    }

    @Test
    void myReviewsUseTheSamePublicShape() throws Exception {
        user("kakao:111", Map.of("nickname", "숨긴닉네임", "nicknamePublic", false));
        query("authorUid", "kakao:111", List.of(review("mine", "kakao:111", "운영자", "2026-10-04T00:00:00Z")));

        List<Map<String, Object>> result = service.getMyReviews("kakao:111");

        assertThat(result).singleElement().satisfies(row -> {
            assertThat(row.keySet()).containsExactlyInAnyOrderElementsOf(PUBLIC_FIELDS);
            assertThat(row).containsEntry("authorName", "익명").containsEntry("storeSource", "GOV")
                    .containsEntry("storeId", "store_a");
        });
    }

    @Test
    void savingAReviewIgnoresTheRequestedAuthorName() throws Exception {
        user("kakao:111", Map.of("nickname", "진짜닉네임", "nicknamePublic", true));
        DocumentReference document = mock(DocumentReference.class);
        when(reviews.document()).thenReturn(document);
        when(document.set(anyMap())).thenReturn(ApiFutures.immediateFuture(null));
        when(document.getId()).thenReturn("new-review");

        FirebaseService.SavedReview saved = service.createReview("kakao:111", request("store_a", "경남식당", "운영자"));

        assertThat(saved).isEqualTo(new FirebaseService.SavedReview("new-review", "진짜닉네임"));
        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, Object>> data = ArgumentCaptor.forClass(Map.class);
        verify(document).set(data.capture());
        assertThat(data.getValue()).containsEntry("authorName", "진짜닉네임")
                .containsEntry("authorUid", "kakao:111");
    }

    @Test
    void privateNicknameIsStoredAsAnonymous() throws Exception {
        user("kakao:222", Map.of("nickname", "숨긴닉네임", "nicknamePublic", false));
        DocumentReference document = mock(DocumentReference.class);
        when(reviews.document()).thenReturn(document);
        when(document.set(anyMap())).thenReturn(ApiFutures.immediateFuture(null));
        when(document.getId()).thenReturn("new-review");

        assertThat(service.createReview("kakao:222", request("store_a", "경남식당", "숨긴닉네임")).authorName())
                .isEqualTo("익명");
    }

    @Test
    void closedStoreKeepsExistingReviewsButRejectsNewOnes() throws Exception {
        user("kakao:111", Map.of("nickname", "단골"));
        query("storeId", "store_closed", List.of(review("old", "kakao:111", "단골", "2026-09-01T00:00:00Z")));

        assertThat(service.getReviews("store_closed")).extracting(row -> row.get("id")).containsExactly("old");
        assertThatThrownBy(() -> service.createReview("kakao:111", request("store_closed", "폐업식당", "단골")))
                .isInstanceOf(IllegalArgumentException.class);
        verify(reviews, never()).document();
    }

    private ReviewRequest request(String storeId, String storeName, String authorName) {
        return ReviewRequest.builder().storeId(storeId).storeName(storeName).authorName(authorName)
                .menu("백반").price(7000).content("맛있어요").stars(4).build();
    }

    private QueryDocumentSnapshot review(String id, String authorUid, String authorName, String createdAt) {
        Map<String, Object> data = new HashMap<>();
        data.put("storeId", "store_a");
        data.put("storeName", "경남식당");
        data.put("storeAddress", "서울 중구");
        if (authorUid != null) data.put("authorUid", authorUid);
        data.put("authorName", authorName);
        data.put("menu", "백반");
        data.put("price", 7000);
        data.put("content", "맛있어요");
        data.put("stars", 4);
        data.put("likes", 0);
        data.put("ownerReply", null);
        data.put("createdAt", createdAt);
        data.put("internalNote", "내부값");
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        when(document.getId()).thenReturn(id);
        when(document.getData()).thenReturn(data);
        return document;
    }

    private void query(String field, String value, List<QueryDocumentSnapshot> documents) {
        Query query = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(reviews.whereEqualTo(field, value)).thenReturn(query);
        when(query.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.getDocuments()).thenReturn(documents);
    }

    private void user(String uid, Map<String, Object> data) {
        DocumentReference reference = mock(DocumentReference.class);
        DocumentSnapshot snapshot = mock(DocumentSnapshot.class);
        when(users.document(uid)).thenReturn(reference);
        when(reference.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.exists()).thenReturn(true);
        when(snapshot.getData()).thenReturn(new HashMap<>(data));
    }

    private void missingUser(String uid) {
        DocumentReference reference = mock(DocumentReference.class);
        DocumentSnapshot snapshot = mock(DocumentSnapshot.class);
        when(users.document(uid)).thenReturn(reference);
        when(reference.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.exists()).thenReturn(false);
    }
}
