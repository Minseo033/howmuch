package com.howmuch.service;

import com.howmuch.HowMuchApplication;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.core.io.ClassPathResource;

import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.google.cloud.firestore.Firestore;

class FirebaseServiceStartupTest {

    @Test
    void storeCacheWarmupRunsAsynchronouslyAfterApplicationIsReady() throws Exception {
        Method warmup = FirebaseService.class.getMethod("warmStoreCaches");
        EventListener listener = warmup.getAnnotation(EventListener.class);

        assertThat(warmup.isAnnotationPresent(PostConstruct.class)).isFalse();
        assertThat(warmup.isAnnotationPresent(Async.class)).isTrue();
        assertThat(listener).isNotNull();
        assertThat(listener.value()).containsExactly(ApplicationReadyEvent.class);
        assertThat(HowMuchApplication.class.isAnnotationPresent(EnableAsync.class)).isTrue();
    }

    @Test
    void verifiedSupplementIsServedButExcludedFromTheRefreshSnapshot() {
        var service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
        Map<String, Object> baseStore = new HashMap<>();
        baseStore.put("storeName", "기본매장");
        baseStore.put("address", "서울특별시 중구 세종대로 1");
        baseStore.put("phoneNumber", "02-000-0000");
        baseStore.put("latitude", 37.56);
        baseStore.put("longitude", 126.97);

        ReflectionTestUtils.invokeMethod(service, "installGovStores", List.of(baseStore));

        assertThat(service.getGovStoresSnapshot()).hasSize(1);
        assertThat(service.getGovStoresSnapshot().getFirst().get("storeName")).isEqualTo("기본매장");
        assertThat(service.getAllStores()).hasSizeGreaterThanOrEqualTo(181);
        assertThat(service.getAllStores()).anyMatch(store -> "헤어스케치".equals(store.get("storeName")));

        // If a later public-data refresh starts carrying the same shop, its phone
        // collision suppresses the supplement row instead of creating a duplicate.
        var futureBase = new HashMap<>(baseStore);
        futureBase.put("phoneNumber", "02-470-5108");
        ReflectionTestUtils.invokeMethod(service, "installGovStores", List.of(futureBase));
        assertThat(service.getGovStoresSnapshot()).hasSize(1);
        assertThat(service.getAllStores()).noneMatch(store -> "헤어스케치".equals(store.get("storeName")));
    }

    @Test
    void bundledBaseAndSupplementMergeToTheReviewedTotal() throws Exception {
        List<Map<String, Object>> stores;
        try (var input = new ClassPathResource("stores-snapshot.json").getInputStream()) {
            stores = new ObjectMapper().readValue(input, new TypeReference<>() {});
        }
        var service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));

        ReflectionTestUtils.invokeMethod(service, "installGovStores", stores);

        assertThat(service.getGovStoresSnapshot()).hasSize(11_207);
        assertThat(service.getAllStores()).hasSize(11_385);
        assertThat(service.getAllStores().stream()
                .map(store -> String.valueOf(store.get("storeId")))
                .distinct()
                .count()).isEqualTo(11_385);
    }

    @Test
    void allStoresIncludesOnlyPublicUserStoresWithoutDuplicatingGovernmentStores() {
        var service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
        Map<String, Object> governmentStore = new HashMap<>(Map.of(
                "storeName", "기존매장",
                "address", "서울특별시 중구 세종대로 1",
                "phoneNumber", "02-000-0000",
                "latitude", 37.56,
                "longitude", 126.97));
        ReflectionTestUtils.invokeMethod(service, "installGovStores", List.of(governmentStore));

        Map<String, Object> approvedUserStore = new HashMap<>(Map.of(
                "storeName", "승인사용자매장",
                "address", "서울특별시 중구 을지로 2",
                "status", "APPROVED",
                "latitude", 37.57,
                "longitude", 126.98));
        approvedUserStore.put("reporterId", "kakao:private-user");
        approvedUserStore.put("description", "비공개 제보 설명");
        approvedUserStore.put("rejectReason", "비공개 반려 사유");
        approvedUserStore.put("imageUrls", List.of("https://private.example/report.jpg"));
        Map<String, Object> pendingUserStore = new HashMap<>(Map.of(
                "storeName", "대기사용자매장",
                "address", "서울특별시 중구 을지로 3",
                "status", "PENDING",
                "latitude", 37.58,
                "longitude", 126.99));
        Map<String, Object> duplicateGovernmentStore = new HashMap<>(governmentStore);
        duplicateGovernmentStore.put("status", "APPROVED");
        duplicateGovernmentStore.put("storeId", "different-submitted-id");
        ReflectionTestUtils.setField(service, "cachedUserStores",
                List.of(approvedUserStore, pendingUserStore, duplicateGovernmentStore));

        List<Map<String, Object>> stores = service.getAllStores();

        assertThat(stores).anySatisfy(store -> {
            assertThat(store.get("storeName")).isEqualTo("승인사용자매장");
            assertThat(store.get("source")).isEqualTo("USER");
            assertThat(store.get("storeId")).isNotNull();
            assertThat(store).doesNotContainKeys(
                    "reporterId", "description", "rejectReason", "imageUrls", "status");
        });
        assertThat(stores).noneMatch(store -> "대기사용자매장".equals(store.get("storeName")));
        assertThat(stores.stream()
                .filter(store -> "기존매장".equals(store.get("storeName"))))
                .hasSize(1)
                .allMatch(store -> "GOV".equals(store.get("source")));
    }
}
