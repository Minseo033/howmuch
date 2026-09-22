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
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.anyMap;

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
    void allStoresResponseIsCachedUntilSourceSnapshotsChange() {
        var service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
        Map<String, Object> firstStore = new HashMap<>(Map.of(
                "storeName", "첫매장",
                "address", "서울특별시 중구 세종대로 1",
                "phoneNumber", "02-000-0000",
                "latitude", 37.56,
                "longitude", 126.97));
        Map<String, Object> nextStore = new HashMap<>(Map.of(
                "storeName", "다음매장",
                "address", "서울특별시 중구 을지로 2",
                "phoneNumber", "02-111-1111",
                "latitude", 37.57,
                "longitude", 126.98));

        ReflectionTestUtils.invokeMethod(service, "installGovStores", List.of(firstStore));
        List<Map<String, Object>> first = service.getAllStores();
        List<Map<String, Object>> second = service.getAllStores();
        assertThat(second).isSameAs(first);

        ReflectionTestUtils.invokeMethod(service, "installGovStores", List.of(nextStore));
        List<Map<String, Object>> refreshed = service.getAllStores();
        assertThat(refreshed).isNotSameAs(first);
        assertThat(refreshed).anyMatch(store -> "다음매장".equals(store.get("storeName")));
        assertThat(refreshed).noneMatch(store -> "첫매장".equals(store.get("storeName")));

        List<Map<String, Object>> sameGovWithUser = List.of(Map.of(
                "storeName", "승인제보매장",
                "address", "서울특별시 중구 퇴계로 3",
                "status", "APPROVED",
                "latitude", 37.58,
                "longitude", 126.99));
        ReflectionTestUtils.setField(service, "cachedUserStores", sameGovWithUser);
        List<Map<String, Object>> refreshedByUser = service.getAllStores();

        assertThat(refreshedByUser).isNotSameAs(refreshed);
        assertThat(refreshedByUser).anyMatch(store -> "승인제보매장".equals(store.get("storeName")));
        assertThat(service.getAllStores()).isSameAs(refreshedByUser);
    }

    @Test
    void allStoresResponseAndNestedOpeningHoursAreImmutableSnapshots() {
        var service = new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class));
        Map<String, Object> firstPeriod = new HashMap<>(Map.of("day", "월", "hours", "09:00-18:00"));
        List<Map<String, Object>> periods = new ArrayList<>();
        periods.add(firstPeriod);
        Map<String, Object> openingHours = new HashMap<>();
        openingHours.put("periods", periods);
        openingHours.put("status", "영업 중");
        // Public hours must come from the reviewed catalog, not an incoming snapshot.
        StoreHoursCatalog hoursCatalog = mock(StoreHoursCatalog.class);
        when(hoursCatalog.findFor(anyMap())).thenReturn(openingHours);
        ReflectionTestUtils.setField(service, "storeHoursCatalog", hoursCatalog);
        Map<String, Object> store = new HashMap<>(Map.of(
                "storeName", "불변매장",
                "address", "서울특별시 중구 세종대로 1",
                "phoneNumber", "02-000-0000",
                "latitude", 37.56,
                "longitude", 126.97,
                "openingHours", openingHours));

        ReflectionTestUtils.invokeMethod(service, "installGovStores", List.of(store));

        List<Map<String, Object>> first = service.getAllStores();
        Map<String, Object> publicStore = first.stream()
                .filter(item -> "불변매장".equals(item.get("storeName")))
                .findFirst()
                .orElseThrow();
        @SuppressWarnings("unchecked")
        Map<String, Object> publicHours = (Map<String, Object>) publicStore.get("openingHours");
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> publicPeriods = (List<Map<String, Object>>) publicHours.get("periods");

        assertThatThrownBy(() -> first.add(Map.of())).isInstanceOf(UnsupportedOperationException.class);
        assertThatThrownBy(() -> publicStore.put("storeName", "수정")).isInstanceOf(UnsupportedOperationException.class);
        assertThatThrownBy(() -> publicHours.put("status", "수정")).isInstanceOf(UnsupportedOperationException.class);
        assertThatThrownBy(() -> publicPeriods.add(Map.of())).isInstanceOf(UnsupportedOperationException.class);
        assertThatThrownBy(() -> publicPeriods.getFirst().put("day", "화"))
                .isInstanceOf(UnsupportedOperationException.class);

        openingHours.put("status", "외부 변경");
        firstPeriod.put("day", "화");

        assertThat(service.getAllStores()).isSameAs(first);
        assertThat(publicHours.get("status")).isEqualTo("영업 중");
        assertThat(publicPeriods.getFirst().get("day")).isEqualTo("월");
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
