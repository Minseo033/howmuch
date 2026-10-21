package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.spy;

class FirebaseServiceTodaysPickNearbyTest {
    private FirebaseService service(List<Map<String, Object>> catalog) {
        var service = spy(new FirebaseService(mock(Firestore.class), mock(ReportImageStorage.class)));
        doReturn(catalog).when(service).getAllStores();
        return service;
    }

    @Test
    void skipsDistantMenuAndPriceWorkForTheNationwideCatalog() {
        var far = new ArrayList<CountingStore>();
        List<Map<String, Object>> stores = new ArrayList<>();
        stores.add(store("near-meal", "김밥", 37.5001, 127.0));
        stores.add(store("near-meal-2", "국수", 37.5002, 127.0));
        stores.add(store("near-cafe", "아메리카노", 37.5003, 127.0));
        for (int i = 0; i < 11_388; i++) {
            var row = new CountingStore();
            row.putAll(store("far-" + i, "김밥", 35.0 + i * .00001, 129.0));
            far.add(row);
            stores.add(row);
        }
        var picks = service(stores).getTodaysPicks("맑음", 20, 37.5, 127.0, 3000);
        assertThat(picks).extracting(p -> p.get("storeId")).containsExactly("near-meal", "near-meal-2", "near-cafe");
        assertThat(far.stream().mapToInt(row -> row.menuReads).sum()).isZero();
    }

    @Test
    void preservesLegacyFallbackPriorityAndInvalidatesThemePresenceWithTheCatalog() {
        var near = List.of(store("a", "백반", 37.5001, 127.0), store("b", "갈비", 37.5002, 127.0),
                store("c", "돈가스", 37.5003, 127.0), store("d", "아메리카노", 37.5004, 127.0));
        List<Map<String, Object>> withGlobalMain = new ArrayList<>(near);
        withGlobalMain.add(store("far-main", "김밥", 35.0, 129.0));
        var service = service(withGlobalMain);
        assertThat(service.getTodaysPicks("맑음", 20, 37.5, 127.0, 3000))
                .extracting(p -> p.get("storeId")).containsExactly("a", "c", "d");
        doReturn(near).when(service).getAllStores();
        assertThat(service.getTodaysPicks("맑음", 20, 37.5, 127.0, 3000))
                .extracting(p -> p.get("storeId")).containsExactly("a", "b", "d");
    }

    @Test
    void selectionAndReasonsMatchThePreviousPipelineAcrossThemesRadiiAndBoundaries() {
        List<Map<String, Object>> stores = new ArrayList<>();
        String[] menus = {"국밥", "김밥", "돈가스", "아메리카노", "백반", "비빔국수", "파전", "삼계탕", "냉면"};
        for (int i = 0; i < 180; i++) {
            var row = store("store-" + i, menus[i % menus.length], 37.5 + (i - 40) * .0008, 127.0 + i * .00003);
            if (i % 11 == 0) row.put("price1", "가격 미정");
            if (i % 13 == 0) { row.put("price1", "0"); row.put("free1", i % 2 == 0); }
            if (i % 17 == 0) row.put("price1", "4000 / 5000");
            stores.add(row);
        }
        stores.add(new HashMap<>(Map.of("storeId", "missing-industry", "menu1", "김밥", "price1", "4000")));
        stores.add(store("invalid-coordinates", "김밥", Double.NaN, 127.0));
        var service = service(stores);
        Object[][] weather = {{"맑음", 20}, {"비", 18}, {"맑음", 32}, {"눈", -3}, {"알 수 없음", null}};
        for (var condition : weather) {
            for (int radius : List.of(1000, 3000, 15000)) {
                String description = condition[0] + "/" + condition[1] + "/" + radius;
                var expected = legacyRows(service, (String) condition[0], (Integer) condition[1], 37.5, 127.0, radius);
                var actual = summary(service.getTodaysPicks((String) condition[0], (Integer) condition[1], 37.5, 127.0, radius));
                assertThat(actual).as(description).isEqualTo(expected);
            }
        }
    }

    @Test
    void conservativeBoundsPreserveAntimeridianPolarAndExactRadiusCases() {
        for (double[] center : List.of(new double[]{.5, 179.99}, new double[]{89.99, 179.99}, new double[]{-89.99, -179.99}, new double[]{37.5, 127.0})) {
            List<Map<String, Object>> stores = new ArrayList<>();
            stores.add(store("wrapped", "김밥", center[0], -center[1]));
            for (double distance : new double[]{999.999, 1000.0, 1000.001, 2999.999, 3000.001}) {
                double latitude = center[0] + Math.toDegrees(distance / 6_371_000.0);
                if (latitude <= 90) stores.add(store("distance-" + distance, "김밥", latitude, center[1]));
            }
            var service = service(stores);
            for (int radius : List.of(1000, 3000, 15000)) {
                assertThat(summary(service.getTodaysPicks("맑음", 20, center[0], center[1], radius)))
                        .isEqualTo(legacyRows(service, "맑음", 20, center[0], center[1], radius));
            }
        }
    }

    private Map<String, Object> store(String id, String menu, double lat, double lng) {
        return new HashMap<>(Map.of("storeId", id, "storeName", id, "industry", "한식", "menu1", menu,
                "price1", "5000", "latitude", lat, "longitude", lng));
    }

    private List<Map<String, Object>> summary(List<Map<String, Object>> picks) {
        return picks.stream().map(row -> Map.of("storeId", row.get("storeId"), "matchedMenu", row.get("matchedMenu"),
                "theme", row.get("theme"), "reason", row.get("reason"), "distanceMeters", row.get("distanceMeters"))).toList();
    }

    /** The pre-change selection pipeline, retaining the original global-before-distance order. */
    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> legacyRows(FirebaseService service, String weather, Integer temp, double lat, double lng, int radius) {
        Set<String> industries = (Set<String>) ReflectionTestUtils.getField(FirebaseService.class, "FOOD_INDUSTRIES");
        var food = service.getAllStores().stream().filter(row -> row.get("industry") != null && industries.contains(row.get("industry"))
                && Boolean.TRUE.equals(ReflectionTestUtils.invokeMethod(service, "hasValidStoreCoordinate", row))
                && ReflectionTestUtils.invokeMethod(service, "firstPricedMenu", row) != null).toList();
        List<?> themes = ReflectionTestUtils.invokeMethod(service, "weatherThemes", weather, temp);
        var menus = new HashMap<String, String>();
        var labels = new HashMap<String, String>();
        var reasons = new HashMap<String, String>();
        List<Map<String, Object>> main = ReflectionTestUtils.invokeMethod(service, "matchTheme", food, themes.getFirst(), menus, labels, reasons, Set.of());
        List<Map<String, Object>> alt = themes.size() > 1
                ? ReflectionTestUtils.invokeMethod(service, "matchTheme", food, themes.get(1), menus, labels, reasons, Set.copyOf(labels.keySet())) : List.of();
        Map<Map<String, Object>, Double> distances = new IdentityHashMap<>();
        long seed = java.time.LocalDate.now(java.time.ZoneId.of("Asia/Seoul")).toEpochDay();
        List<Map<String, Object>> mainCandidates = ReflectionTestUtils.invokeMethod(service, "nearestShuffled", main.isEmpty() ? food : main, lat, lng, 20, seed, (double) radius, distances);
        List<Map<String, Object>> altCandidates = ReflectionTestUtils.invokeMethod(service, "nearestShuffled", alt, lat, lng, 10, seed + 1, (double) radius, distances);
        List<Map<String, Object>> nearby = ReflectionTestUtils.invokeMethod(service, "nearestShuffled", food, lat, lng, 20, seed + 2, (double) radius, distances);
        var preferred = new ArrayList<Map<String, Object>>();
        var seen = new HashSet<String>();
        for (var pool : List.of(mainCandidates, altCandidates, nearby)) ReflectionTestUtils.invokeMethod(service, "addUnique", preferred, pool, 20, seen);
        var meals = preferred.stream().filter(row -> !Boolean.TRUE.equals(ReflectionTestUtils.invokeMethod(service, "isDessertStore", row))).toList();
        var desserts = preferred.stream().filter(row -> Boolean.TRUE.equals(ReflectionTestUtils.invokeMethod(service, "isDessertStore", row))).toList();
        var chosen = new ArrayList<Map<String, Object>>();
        seen.clear();
        ReflectionTestUtils.invokeMethod(service, "addUnique", chosen, meals, 2, seen);
        ReflectionTestUtils.invokeMethod(service, "addUnique", chosen, desserts, 3 - chosen.size(), seen);
        ReflectionTestUtils.invokeMethod(service, "addUnique", chosen, preferred, 3 - chosen.size(), seen);
        chosen.sort(Comparator.comparingDouble(row -> distance(row, lat, lng)));
        return chosen.stream().map(row -> {
            String id = String.valueOf(row.get("storeId"));
            String menu = menus.get(id);
            if (menu == null || menu.isBlank()) menu = ReflectionTestUtils.invokeMethod(service, "firstPricedMenu", row);
            return Map.<String, Object>of("storeId", id, "matchedMenu", menu,
                    "theme", labels.getOrDefault(id, "주변 매장"), "reason", reasons.getOrDefault(id, "선택한 거리 안에서 가까운 매장이에요."),
                    "distanceMeters", (int) Math.round(distance(row, lat, lng)));
        }).toList();
    }

    private double distance(Map<String, Object> row, double lat, double lng) {
        double aLat = Double.parseDouble(row.get("latitude").toString());
        double aLng = Double.parseDouble(row.get("longitude").toString());
        double a = Math.pow(Math.sin(Math.toRadians(aLat - lat) / 2), 2)
                + Math.cos(Math.toRadians(lat)) * Math.cos(Math.toRadians(aLat)) * Math.pow(Math.sin(Math.toRadians(aLng - lng) / 2), 2);
        return 6_371_000.0 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private static final class CountingStore extends HashMap<String, Object> {
        int menuReads;
        @Override public Object get(Object key) {
            if (key instanceof String text && (text.startsWith("menu") || text.startsWith("price") || text.startsWith("free"))) menuReads++;
            return super.get(key);
        }
    }
}
