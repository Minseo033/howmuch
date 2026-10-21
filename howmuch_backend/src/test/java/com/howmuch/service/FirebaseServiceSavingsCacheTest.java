package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.api.core.SettableApiFuture;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.Query;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.howmuch.dto.SavingsHistoryResponse;
import com.howmuch.dto.SavingsStatsResponse;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.IOException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class FirebaseServiceSavingsCacheTest {
    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-10-21T00:00:00Z"), ZoneOffset.UTC);

    @Test
    void simultaneousPeriodsShareOneVisitReadAndDoNotBuildTheNationalCatalog() throws Exception {
        Fixture fixture = new Fixture();
        SettableApiFuture<QuerySnapshot> pending = SettableApiFuture.create();
        when(fixture.query.get()).thenReturn(pending);
        List<Thread> threads = new CopyOnWriteArrayList<>();
        try (var executor = Executors.newFixedThreadPool(3, task -> {
            Thread thread = new Thread(task);
            threads.add(thread);
            return thread;
        })) {
            SavingsService savings = new SavingsService(fixture.service, CLOCK);
            List<Future<SavingsStatsResponse>> requests = new ArrayList<>();
            for (String period : List.of("this_month", "last_month", "this_year")) {
                requests.add(executor.submit(() -> savings.getSavingsStats("user-1", period)));
            }
            try {
                await().atMost(Duration.ofSeconds(5)).until(() -> threads.size() == 3
                        && threads.stream().allMatch(thread -> thread.getState() == Thread.State.WAITING));
                verify(fixture.query, times(1)).get();
            } finally {
                pending.set(snapshot("before"));
            }
            assertThat(requests.get(0).get(5, TimeUnit.SECONDS).getTotalSavedAmount()).isEqualTo(2000L);
            assertThat(requests.get(1).get(5, TimeUnit.SECONDS).getTotalSavedAmount()).isZero();
            assertThat(requests.get(2).get(5, TimeUnit.SECONDS).getTotalSavedAmount()).isEqualTo(2000L);
            verify(fixture.query, times(1)).get();
            assertThat(ReflectionTestUtils.getField(fixture.service, "allStoresCache")).isNull();
        }
    }

    @Test
    void aMutationDuringAnOldReadCannotReplaceOrReturnTheNewSnapshot() throws Exception {
        Fixture fixture = new Fixture();
        SettableApiFuture<QuerySnapshot> pending = SettableApiFuture.create();
        QuerySnapshot after = snapshot("after");
        when(fixture.query.get()).thenReturn(pending, ApiFutures.immediateFuture(after));
        try (var executor = Executors.newSingleThreadExecutor()) {
            Future<List<SavingsHistoryResponse>> oldRead = executor.submit(
                    () -> fixture.service.getSavingsStatsHistory("user-1"));
            try {
                verify(fixture.query, timeout(5000)).get();
                fixture.service.invalidateSavingsHistory("user-1");
                assertThat(fixture.service.getSavingsStatsHistory("user-1"))
                        .extracting(SavingsHistoryResponse::getId).containsExactly("after");
            } finally {
                pending.set(snapshot("before"));
            }
            assertThat(oldRead.get(5, TimeUnit.SECONDS))
                    .extracting(SavingsHistoryResponse::getId).containsExactly("after");
            assertThat(fixture.service.getSavingsStatsHistory("user-1"))
                    .extracting(SavingsHistoryResponse::getId).containsExactly("after");
            verify(fixture.query, times(2)).get();
        }
    }

    @Test
    void userSnapshotsAreIsolatedAndHistoryEnrichmentCannotMutateTheCachedStats() throws Exception {
        Fixture fixture = new Fixture();
        Query otherQuery = mock(Query.class);
        QuerySnapshot one = snapshot("one");
        QuerySnapshot two = snapshot("two");
        when(fixture.visits.whereEqualTo("userId", "user-2")).thenReturn(otherQuery);
        when(fixture.query.get()).thenReturn(ApiFutures.immediateFuture(one));
        when(otherQuery.get()).thenReturn(ApiFutures.immediateFuture(two));
        ReflectionTestUtils.setField(fixture.service, "cachedStores", List.of(Map.of(
                "storeId", "store_gov", "storeName", "식당", "address", "서울 중구")));

        assertThat(fixture.service.getSavingsStatsHistory("user-1"))
                .extracting(SavingsHistoryResponse::getId).containsExactly("one");
        assertThat(fixture.service.getSavingsStatsHistory("user-2"))
                .extracting(SavingsHistoryResponse::getId).containsExactly("two");
        assertThat(fixture.service.getSavingsHistory("user-1").getFirst().getStoreSource()).isEqualTo("GOV");
        assertThat(fixture.service.getSavingsStatsHistory("user-1").getFirst().getStoreSource()).isNull();
        verify(fixture.query, times(1)).get();
        verify(otherQuery, times(1)).get();
    }

    @Test
    void failedReadsAreNotCachedAndCanBeRetried() throws Exception {
        Fixture fixture = new Fixture();
        QuerySnapshot recovered = snapshot("recovered");
        when(fixture.query.get()).thenReturn(ApiFutures.immediateFailedFuture(new IOException("temporary")),
                ApiFutures.immediateFuture(recovered));
        assertThatThrownBy(() -> fixture.service.getSavingsStatsHistory("user-1"))
                .hasCauseInstanceOf(IOException.class);
        assertThat(fixture.service.getSavingsStatsHistory("user-1"))
                .extracting(SavingsHistoryResponse::getId).containsExactly("recovered");
        verify(fixture.query, times(2)).get();
    }

    @Test
    void completedSnapshotsExpireAndHaveABoundedAccountCount() throws Exception {
        Fixture fixture = new Fixture();
        QuerySnapshot current = snapshot("current");
        when(fixture.visits.whereEqualTo(eq("userId"), anyString())).thenReturn(fixture.query);
        when(fixture.query.get()).thenReturn(ApiFutures.immediateFuture(current));
        fixture.service.getSavingsStatsHistory("user-1");
        @SuppressWarnings("unchecked")
        Map<String, ?> cache = (Map<String, ?>) ReflectionTestUtils.getField(fixture.service, "savingsHistoryCache");
        ReflectionTestUtils.setField(cache.get("user-1"), "cachedAtMs", System.currentTimeMillis() - 30_001L);
        fixture.service.getSavingsStatsHistory("user-1");
        verify(fixture.query, times(2)).get();
        for (int account = 2; account <= 257; account++) {
            fixture.service.getSavingsStatsHistory("user-" + account);
        }
        assertThat(cache).hasSize(256).doesNotContainKey("user-1").containsKey("user-257");
    }

    @Test
    void aCommittedVisitDeletionInvalidatesAnAlreadyCachedSnapshot() throws Exception {
        Fixture fixture = new Fixture();
        var document = mock(com.google.cloud.firestore.DocumentReference.class);
        var owned = mock(com.google.cloud.firestore.DocumentSnapshot.class);
        when(fixture.visits.document("owned")).thenReturn(document);
        when(document.get()).thenReturn(ApiFutures.immediateFuture(owned));
        when(owned.exists()).thenReturn(true);
        when(owned.getString("userId")).thenReturn("user-1");
        when(document.delete()).thenReturn(ApiFutures.immediateFuture(null));
        QuerySnapshot before = snapshot("before");
        QuerySnapshot empty = emptySnapshot();
        when(fixture.query.get()).thenReturn(ApiFutures.immediateFuture(before), ApiFutures.immediateFuture(empty));
        fixture.service.getSavingsStatsHistory("user-1");
        fixture.service.deleteOwnedVisit("owned", "user-1");
        assertThat(fixture.service.getSavingsStatsHistory("user-1")).isEmpty();
        verify(fixture.query, times(2)).get();
    }

    @Test
    void missingIdentityNeverQueriesVisits() throws Exception {
        Fixture fixture = new Fixture();
        clearInvocations(fixture.db);
        assertThat(fixture.service.getSavingsStatsHistory(null)).isEmpty();
        assertThat(fixture.service.getSavingsStatsHistory(" ")).isEmpty();
        assertThat(fixture.service.getSavingsHistory(null)).isEmpty();
        verifyNoInteractions(fixture.db);
    }

    private static QuerySnapshot snapshot(String id) {
        QueryDocumentSnapshot visit = mock(QueryDocumentSnapshot.class);
        when(visit.getId()).thenReturn(id);
        when(visit.getData()).thenReturn(Map.of(
                "storeId", "store_gov", "storeName", "식당", "industry", "한식",
                "visitDate", "2026-10-05", "savedAmount", 2000L, "price", 4000L));
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(snapshot.getDocuments()).thenReturn(List.of(visit));
        return snapshot;
    }

    private static QuerySnapshot emptySnapshot() {
        QuerySnapshot snapshot = mock(QuerySnapshot.class);
        when(snapshot.getDocuments()).thenReturn(List.of());
        return snapshot;
    }

    private static final class Fixture {
        final Firestore db = mock(Firestore.class);
        final CollectionReference visits = mock(CollectionReference.class);
        final Query query = mock(Query.class);
        final FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));

        Fixture() {
            when(db.collection("visits")).thenReturn(visits);
            when(visits.whereEqualTo("userId", "user-1")).thenReturn(query);
        }
    }
}
