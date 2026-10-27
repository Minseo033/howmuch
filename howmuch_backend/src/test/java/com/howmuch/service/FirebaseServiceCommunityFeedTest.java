package com.howmuch.service;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QuerySnapshot;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FirebaseServiceCommunityFeedTest {

    @Test
    void requestsTheNewestCommunityDocumentsBeforeApplyingTheLimit() throws Exception {
        Firestore firestore = mock(Firestore.class);
        ReportImageStorage imageStorage = mock(ReportImageStorage.class);
        CollectionReference collection = mock(CollectionReference.class);
        Query ordered = mock(Query.class);
        Query limited = mock(Query.class);
        @SuppressWarnings("unchecked")
        ApiFuture<QuerySnapshot> future = mock(ApiFuture.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(firestore.collection("stores_user")).thenReturn(collection);
        when(collection.orderBy("createdAt", Query.Direction.DESCENDING)).thenReturn(ordered);
        when(ordered.limit(25)).thenReturn(limited);
        when(limited.get()).thenReturn(future);
        when(future.get()).thenReturn(snapshot);
        when(snapshot.getDocuments()).thenReturn(List.of());
        FirebaseService service = new FirebaseService(firestore, imageStorage);
        ReflectionTestUtils.setField(service, "communityFeedMaxItems", 25);

        assertThat(service.getCommunityFeeds()).isEmpty();

        verify(collection).orderBy("createdAt", Query.Direction.DESCENDING);
        verify(ordered).limit(25);
    }

    @Test
    void reusesTheFeedCacheWithinTheTtl() throws Exception {
        FeedFixture fixture = feedFixture();

        assertThat(fixture.service().getCommunityFeeds()).isEmpty();
        assertThat(fixture.service().getCommunityFeeds()).isEmpty();

        verify(fixture.limited(), times(1)).get();
    }

    @Test
    void refreshesTheFeedCacheOnlyOnceForConcurrentMisses() throws Exception {
        FeedFixture fixture = feedFixture();
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        try {
            Future<List<com.howmuch.dto.FeedResponseDto>> first = executor.submit(() -> {
                start.await();
                return fixture.service().getCommunityFeeds();
            });
            Future<List<com.howmuch.dto.FeedResponseDto>> second = executor.submit(() -> {
                start.await();
                return fixture.service().getCommunityFeeds();
            });

            start.countDown();
            assertThat(first.get()).isEmpty();
            assertThat(second.get()).isEmpty();
            verify(fixture.limited(), times(1)).get();
        } finally {
            executor.shutdownNow();
        }
    }

    @Test
    void feedCounterSynchronizationInvalidatesTheCachedCountsEvenOnFailure() {
        Firestore firestore = mock(Firestore.class);
        FirebaseService service = new FirebaseService(firestore, mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(service, "cachedFeeds", List.of(
                com.howmuch.dto.FeedResponseDto.builder().id("feed-1").likes(1).comments(1).build()));
        ReflectionTestUtils.setField(service, "lastFeedsCacheTime", System.currentTimeMillis());

        ReflectionTestUtils.invokeMethod(service, "syncFeedCounts", "feed-1");

        assertThat(ReflectionTestUtils.getField(service, "cachedFeeds")).isNull();
        assertThat(ReflectionTestUtils.getField(service, "lastFeedsCacheTime")).isEqualTo(0L);
    }

    @Test
    @SuppressWarnings("unchecked")
    void signedInFeedMarksOwnLikesWithoutChangingTheSharedCache() throws Exception {
        Firestore firestore = mock(Firestore.class);
        CollectionReference likes = mock(CollectionReference.class);
        Query mine = mock(Query.class);
        ApiFuture<QuerySnapshot> future = mock(ApiFuture.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        com.google.cloud.firestore.QueryDocumentSnapshot like =
                mock(com.google.cloud.firestore.QueryDocumentSnapshot.class);
        when(firestore.collection("feed_likes")).thenReturn(likes);
        when(likes.whereEqualTo("userId", "user-1")).thenReturn(mine);
        when(mine.get()).thenReturn(future);
        when(future.get()).thenReturn(snapshot);
        when(like.getString("postId")).thenReturn("feed-2");
        when(snapshot.getDocuments()).thenReturn(List.of(like));
        FirebaseService service = new FirebaseService(firestore, mock(ReportImageStorage.class));
        List<com.howmuch.dto.FeedResponseDto> shared = List.of(
                com.howmuch.dto.FeedResponseDto.builder().id("feed-1").likes(0).build(),
                com.howmuch.dto.FeedResponseDto.builder().id("feed-2").likes(3).build());
        ReflectionTestUtils.setField(service, "cachedFeeds", shared);
        ReflectionTestUtils.setField(service, "lastFeedsCacheTime", System.currentTimeMillis());

        var personal = service.getCommunityFeeds("user-1");

        assertThat(personal).extracting(com.howmuch.dto.FeedResponseDto::isLikedByMe).containsExactly(false, true);
        assertThat(personal.get(1).getLikes()).isEqualTo(3);
        assertThat(shared).extracting(com.howmuch.dto.FeedResponseDto::isLikedByMe).containsExactly(false, false);
        // Signed-out requests read no like documents at all.
        assertThat(service.getCommunityFeeds((String) null))
                .extracting(com.howmuch.dto.FeedResponseDto::isLikedByMe).containsExactly(false, false);
        verify(likes, times(1)).whereEqualTo("userId", "user-1");
    }

    @Test
    @SuppressWarnings("unchecked")
    void successfulCounterSyncUpdatesOnlyThatPostInTheCachedFeed() throws Exception {
        Firestore firestore = mock(Firestore.class);
        for (var entry : java.util.Map.of("comments", 4L, "feed_likes", 7L).entrySet()) {
            CollectionReference collection = mock(CollectionReference.class);
            Query byPost = mock(Query.class);
            com.google.cloud.firestore.AggregateQuery count = mock(com.google.cloud.firestore.AggregateQuery.class);
            ApiFuture<com.google.cloud.firestore.AggregateQuerySnapshot> future = mock(ApiFuture.class);
            com.google.cloud.firestore.AggregateQuerySnapshot result =
                    mock(com.google.cloud.firestore.AggregateQuerySnapshot.class);
            when(firestore.collection(entry.getKey())).thenReturn(collection);
            when(collection.whereEqualTo("postId", "feed-1")).thenReturn(byPost);
            when(byPost.count()).thenReturn(count);
            when(count.get()).thenReturn(future);
            when(future.get()).thenReturn(result);
            when(result.getCount()).thenReturn(entry.getValue());
        }
        CollectionReference reports = mock(CollectionReference.class);
        com.google.cloud.firestore.DocumentReference post = mock(com.google.cloud.firestore.DocumentReference.class);
        when(firestore.collection("stores_user")).thenReturn(reports);
        when(reports.document("feed-1")).thenReturn(post);
        when(post.update(org.mockito.ArgumentMatchers.anyMap()))
                .thenReturn(com.google.api.core.ApiFutures.immediateFuture(null));
        FirebaseService service = new FirebaseService(firestore, mock(ReportImageStorage.class));
        long cachedAt = System.currentTimeMillis();
        ReflectionTestUtils.setField(service, "cachedFeeds", List.of(
                com.howmuch.dto.FeedResponseDto.builder().id("feed-1").likes(1).comments(1).build(),
                com.howmuch.dto.FeedResponseDto.builder().id("feed-2").likes(2).comments(2).build()));
        ReflectionTestUtils.setField(service, "lastFeedsCacheTime", cachedAt);

        ReflectionTestUtils.invokeMethod(service, "syncFeedCounts", "feed-1");

        var cached = (List<com.howmuch.dto.FeedResponseDto>) ReflectionTestUtils.getField(service, "cachedFeeds");
        assertThat(cached).extracting(com.howmuch.dto.FeedResponseDto::getLikes).containsExactly(7, 2);
        assertThat(cached).extracting(com.howmuch.dto.FeedResponseDto::getComments).containsExactly(4, 2);
        assertThat(ReflectionTestUtils.getField(service, "lastFeedsCacheTime")).isEqualTo(cachedAt);
    }

    private FeedFixture feedFixture() throws Exception {
        Firestore firestore = mock(Firestore.class);
        CollectionReference collection = mock(CollectionReference.class);
        Query ordered = mock(Query.class);
        Query limited = mock(Query.class);
        @SuppressWarnings("unchecked")
        ApiFuture<QuerySnapshot> future = mock(ApiFuture.class);
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(firestore.collection("stores_user")).thenReturn(collection);
        when(collection.orderBy("createdAt", Query.Direction.DESCENDING)).thenReturn(ordered);
        when(ordered.limit(25)).thenReturn(limited);
        when(limited.get()).thenReturn(future);
        when(future.get()).thenAnswer(invocation -> {
            Thread.sleep(50);
            return snapshot;
        });
        when(snapshot.getDocuments()).thenReturn(List.of());
        FirebaseService service = new FirebaseService(firestore, mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(service, "communityFeedMaxItems", 25);
        return new FeedFixture(service, limited);
    }

    private record FeedFixture(FirebaseService service, Query limited) { }
}
