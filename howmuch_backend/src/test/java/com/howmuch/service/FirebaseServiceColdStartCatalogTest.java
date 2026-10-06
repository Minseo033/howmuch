package com.howmuch.service;

import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import com.google.cloud.firestore.QuerySnapshot;
import com.google.cloud.firestore.WriteResult;
import jakarta.annotation.PostConstruct;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** BE-CORE-7(콜드스타트 빈 목록)과 BE-CORE-25(건수 급감 갱신 보류) */
class FirebaseServiceColdStartCatalogTest {
    @TempDir
    Path tempDir;

    @Test
    void bundledSnapshotIsLoadedSynchronouslyBeforeServingWithoutFirestore() throws Exception {
        Firestore db = mock(Firestore.class);
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(service, "snapshotPath", tempDir.resolve("missing.json").toString());

        assertThat(FirebaseService.class.getDeclaredMethod("loadBundledStoresBeforeServing")
                .isAnnotationPresent(PostConstruct.class)).isTrue();
        assertThat(service.isStoreCatalogWarmingUp()).isTrue();
        ReflectionTestUtils.invokeMethod(service, "loadBundledStoresBeforeServing");

        assertThat(service.getGovStoresSnapshot()).hasSize(11_207);
        assertThat(service.getAllStores()).hasSize(11_385);
        assertThat(service.isStoreCatalogWarmingUp()).isTrue();
        org.mockito.Mockito.verifyNoInteractions(db);
    }

    @Test
    void warmupFinishesTheCatalogWithoutReloadingTheBundledSnapshot() throws Exception {
        Firestore db = mock(Firestore.class);
        for (String name : List.of("store_corrections", "stores_user")) {
            CollectionReference collection = mock(CollectionReference.class);
            QuerySnapshot empty = mock(QuerySnapshot.class);
            when(db.collection(name)).thenReturn(collection);
            when(collection.get()).thenReturn(ApiFutures.immediateFuture(empty));
            when(empty.getDocuments()).thenReturn(List.of());
        }
        FirebaseService service = new FirebaseService(db, mock(ReportImageStorage.class));
        ReflectionTestUtils.setField(service, "snapshotPath", tempDir.resolve("missing.json").toString());
        ReflectionTestUtils.invokeMethod(service, "loadBundledStoresBeforeServing");
        Object loaded = ReflectionTestUtils.getField(service, "cachedStores");

        service.warmStoreCaches();

        assertThat(ReflectionTestUtils.getField(service, "cachedStores")).isSameAs(loaded);
        assertThat(service.isStoreCatalogWarmingUp()).isFalse();
    }

    @Test
    void aRefreshThatShrinksTheCatalogSharplyIsNotInstalled() throws Exception {
        Fixture fixture = new Fixture(tempDir, 50);
        ReflectionTestUtils.invokeMethod(fixture.service, "installGovStores", stores(100, "기존"));

        fixture.service.refreshGovStores();

        assertThat(fixture.service.getGovStoresSnapshot()).hasSize(100);
        assertThat(Files.exists(tempDir.resolve("snapshot.json"))).isFalse();
        verify(fixture.meta).set(Map.of("lastRefreshAt",
                ReflectionTestUtils.getField(fixture.service, "lastGovRefreshSuccessMillis"),
                "lastRejectedCount", 50, "lastAcceptedCount", 100));
    }

    @Test
    void aNormalRefreshIsInstalledAndPersisted() throws Exception {
        Fixture fixture = new Fixture(tempDir, 90);
        ReflectionTestUtils.invokeMethod(fixture.service, "installGovStores", stores(100, "기존"));

        fixture.service.refreshGovStores();

        assertThat(fixture.service.getGovStoresSnapshot()).hasSize(90);
        assertThat(Files.exists(tempDir.resolve("snapshot.json"))).isTrue();
    }

    private static List<Map<String, Object>> stores(int count, String prefix) {
        List<Map<String, Object>> stores = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            stores.add(Map.of("storeName", prefix + i, "address", "서울 중구 " + i,
                    "phoneNumber", String.format("02-%03d-%04d", i, i), "latitude", 37.5, "longitude", 127.0));
        }
        return stores;
    }

    private static final class Fixture {
        final FirebaseService service;
        final DocumentReference meta = mock(DocumentReference.class);

        Fixture(Path tempDir, int incoming) throws Exception {
            Firestore db = mock(Firestore.class);
            CollectionReference metaCollection = mock(CollectionReference.class);
            DocumentSnapshot missingMeta = mock(DocumentSnapshot.class);
            when(db.collection("meta")).thenReturn(metaCollection);
            when(metaCollection.document("govStores")).thenReturn(meta);
            when(meta.get()).thenReturn(ApiFutures.immediateFuture(missingMeta));
            when(meta.set(anyMap())).thenReturn(ApiFutures.immediateFuture(mock(WriteResult.class)));
            CollectionReference storesCollection = mock(CollectionReference.class);
            QuerySnapshot snapshot = mock(QuerySnapshot.class);
            when(db.collection("stores")).thenReturn(storesCollection);
            when(storesCollection.get()).thenReturn(ApiFutures.immediateFuture(snapshot));
            List<QueryDocumentSnapshot> documents = new ArrayList<>();
            for (Map<String, Object> store : stores(incoming, "새")) {
                QueryDocumentSnapshot document = mock(QueryDocumentSnapshot.class);
                when(document.getData()).thenReturn(store);
                documents.add(document);
            }
            when(snapshot.getDocuments()).thenReturn(documents);
            service = new FirebaseService(db, mock(ReportImageStorage.class));
            ReflectionTestUtils.setField(service, "snapshotPath", tempDir.resolve("snapshot.json").toString());
        }
    }
}

