package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.howmuch.dto.FeedResponseDto;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** 계약 C8(닉네임 비공개는 "익명"·사진 없음)과 C2(피드 changeType·reportType·cityProvince). */
class FirebaseServiceCommunityPrivacyTest {
    private final Firestore db = mock(Firestore.class);
    private final CollectionReference reports = mock(CollectionReference.class);
    private final CollectionReference users = mock(CollectionReference.class);
    private final FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

    @BeforeEach
    void setUp() {
        when(db.collection("stores_user")).thenReturn(reports);
        when(db.collection("users")).thenReturn(users);
        user("kakao:private", Map.of("nickname", "숨긴닉네임", "nicknamePublic", false,
                "profileImageUrl", "https://img/private.jpg"));
        user("kakao:public", Map.of("nickname", "동네이웃", "profileImageUrl", "https://img/public.jpg"));
        user("kakao:noimage", Map.of("nickname", "사진없음"));
    }

    @Test
    void feedHidesPrivateAuthorsAndCarriesChangeTypeAndProvince() throws Exception {
        List<QueryDocumentSnapshot> documents = List.of(
                post("private-post", "kakao:private", "RISE", "서울", "2026-10-05T00:00:00Z", "https://img/legacy.jpg"),
                post("public-post", "kakao:public", null, null, "2026-10-04T00:00:00Z", null),
                post("anonymized-post", "", "delete", "부산", "2026-10-03T00:00:00Z", "https://img/legacy.jpg"),
                post("legacy-image-post", "kakao:noimage", "unknown", "대구", "2026-10-02T00:00:00Z", "https://img/legacy.jpg"));
        feedQuery(documents);

        List<FeedResponseDto> feed = service.getCommunityFeeds();

        assertThat(feed).extracting(FeedResponseDto::getId)
                .containsExactly("private-post", "public-post", "anonymized-post", "legacy-image-post");
        assertThat(feed).extracting(FeedResponseDto::getAuthor)
                .containsExactly("익명", "동네이웃", "알 수 없음", "사진없음");
        assertThat(feed).extracting(FeedResponseDto::getAuthorProfileImageUrl)
                .containsExactly(null, "https://img/public.jpg", null, "https://img/legacy.jpg");
        assertThat(feed).extracting(FeedResponseDto::getChangeType)
                .containsExactly("rise", null, "delete", null);
        assertThat(feed).extracting(FeedResponseDto::getCityProvince)
                .containsExactly("서울", null, "부산", "대구");
        assertThat(feed).extracting(FeedResponseDto::getReportType).containsOnlyNulls();
        assertThat(feed).extracting(FeedResponseDto::getLocation).containsOnly("중구");
    }

    @Test
    void detailAndCommentsHidePrivateAuthorsToo() throws Exception {
        DocumentReference postRef = mock(DocumentReference.class);
        DocumentSnapshot postSnapshot = mock(DocumentSnapshot.class);
        when(reports.document("private-post")).thenReturn(postRef);
        when(postRef.get()).thenReturn(ApiFutures.immediateFuture(postSnapshot));
        when(postSnapshot.exists()).thenReturn(true);
        when(postSnapshot.getId()).thenReturn("private-post");
        when(postSnapshot.getData()).thenReturn(postData("kakao:private", "drop", "서울", "2026-10-05T00:00:00Z", null));

        var detail = service.getCommunityFeedDetail("private-post", null);
        assertThat(detail.getAuthor()).isEqualTo("익명");
        assertThat(detail.getAuthorProfileImageUrl()).isNull();
        assertThat(detail.getChangeType()).isEqualTo("drop");
        assertThat(detail.getCityProvince()).isEqualTo("서울");

        CollectionReference comments = mock(CollectionReference.class);
        Query byPost = mock(Query.class);
        Query topLevel = mock(Query.class);
        Query ordered = mock(Query.class);
        Query limited = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(db.collection("comments")).thenReturn(comments);
        when(comments.whereEqualTo("postId", "private-post")).thenReturn(byPost);
        when(byPost.whereEqualTo("parentId", null)).thenReturn(topLevel);
        when(topLevel.orderBy("createdAt", Query.Direction.ASCENDING)).thenReturn(ordered);
        when(ordered.limit(200)).thenReturn(limited);
        when(limited.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        QueryDocumentSnapshot privateComment = comment("c1", "kakao:private");
        QueryDocumentSnapshot publicComment = comment("c2", "kakao:public");
        List<QueryDocumentSnapshot> commentDocuments = List.of(privateComment, publicComment);
        when(snapshot.getDocuments()).thenReturn(commentDocuments);

        var result = service.getComments("private-post", "viewer");
        assertThat(result).extracting("author").containsExactly("익명", "동네이웃");
        assertThat(result).extracting("authorProfileImageUrl").containsExactly(null, "https://img/public.jpg");
    }

    private void feedQuery(List<QueryDocumentSnapshot> documents) {
        Query ordered = mock(Query.class);
        Query limited = mock(Query.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(reports.orderBy("createdAt", Query.Direction.DESCENDING)).thenReturn(ordered);
        when(ordered.limit(500)).thenReturn(limited);
        when(limited.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.getDocuments()).thenReturn(documents);
    }

    private QueryDocumentSnapshot post(String id, String reporterId, String changeType, String province,
                                       String createdAt, String legacyImage) {
        Map<String, Object> data = postData(reporterId, changeType, province, createdAt, legacyImage);
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        when(document.getId()).thenReturn(id);
        when(document.getData()).thenReturn(data);
        return document;
    }

    private Map<String, Object> postData(String reporterId, String changeType, String province,
                                         String createdAt, String legacyImage) {
        Map<String, Object> data = new HashMap<>();
        data.put("reporterId", reporterId);
        data.put("storeName", "국밥집");
        data.put("menu1", "국밥");
        data.put("price1", "8000");
        data.put("cityDistrict", "중구");
        data.put("status", "APPROVED");
        data.put("createdAt", createdAt);
        if (changeType != null) data.put("changeType", changeType);
        if (province != null) data.put("cityProvince", province);
        if (legacyImage != null) data.put("reporterProfileImageUrl", legacyImage);
        return data;
    }

    private QueryDocumentSnapshot comment(String id, String userId) {
        QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
        when(document.getId()).thenReturn(id);
        when(document.getData()).thenReturn(Map.of("userId", userId, "content", "내용",
                "createdAt", "2026-10-05T00:00:00Z", "replyCount", 0));
        return document;
    }

    private void user(String uid, Map<String, Object> data) {
        DocumentReference reference = mock(DocumentReference.class);
        DocumentSnapshot snapshot = mock(DocumentSnapshot.class);
        when(users.document(uid)).thenReturn(reference);
        when(reference.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
        when(snapshot.exists()).thenReturn(true);
        when(snapshot.getData()).thenReturn(new HashMap<>(data));
    }
}
