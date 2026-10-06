package com.howmuch.service;

import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class GeminiServiceTest {

    @Test
    void springCreatesTheServiceWhenMultipleConstructorsExist() {
        try (AnnotationConfigApplicationContext context = new AnnotationConfigApplicationContext()) {
            context.register(GeminiService.class);
            context.refresh();

            assertThat(context.getBean(GeminiService.class)).isNotNull();
        }
    }

    @Test
    void localRouteDoesNotDuplicateTheWonSuffix() {
        GeminiService service = new GeminiService("", 1_000, false);

        String route = service.getRouteRecommendation(List.of(
                Map.of(
                        "storeName", "실제 매장",
                        "menu1", "아메리카노",
                        "price1", "2,000원",
                        "distanceMeters", 120),
                Map.of(
                        "storeName", "다른 매장",
                        "menu1", "국수",
                        "price1", "5000",
                        "distanceMeters", 300)));

        assertThat(route).contains("2,000원", "5000원");
        assertThat(route).doesNotContain("원원");
    }

    @Test
    void routeFallsBackWhenAiRouteIsEnabledWithoutAKey() {
        GeminiService service = new GeminiService("", 1_000, true);

        String route = service.getRouteRecommendation(List.of(
                Map.of("storeName", "먼 매장", "menu1", "국수", "price1", "5,000", "distanceMeters", 500),
                Map.of("storeName", "가까운 매장", "menu1", "김밥", "price1", "3,000", "distanceMeters", 100)));

        assertThat(route).contains("가까운 매장", "거리순으로 추천 루트");
        assertThat(route.indexOf("가까운 매장")).isLessThan(route.indexOf("먼 매장"));
    }

    @Test
    void candidateUrlsLeadWithConfiguredModelAndModernFlashEndpoints() {
        GeminiService defaultService = new GeminiService("", 1_000, false);
        List<String> defaultUrls = defaultService.getCandidateUrls();
        assertThat(defaultUrls).isNotEmpty();
        assertThat(defaultUrls.get(0)).contains("gemini-3.6-flash:generateContent");

        GeminiService customService = new GeminiService("", 1_000, false, "gemini-3.5-flash-lite");
        List<String> customUrls = customService.getCandidateUrls();
        assertThat(customUrls.get(0)).contains("gemini-3.5-flash-lite:generateContent");

        GeminiService staleConfiguredService = new GeminiService("", 1_000, false, "gemini-1.5-flash");
        assertThat(staleConfiguredService.getCandidateUrls().get(0))
                .contains("gemini-1.5-flash:generateContent");
    }

    @Test
    void localRouteSupportsUpTo4Picks() {
        GeminiService service = new GeminiService("", 1_000, false);
        String route = service.getRouteRecommendation(List.of(
                Map.of("storeName", "매장1", "menu1", "메뉴1", "price1", "1,000", "distanceMeters", 100),
                Map.of("storeName", "매장2", "menu1", "메뉴2", "price1", "2,000", "distanceMeters", 200),
                Map.of("storeName", "매장3", "menu1", "메뉴3", "price1", "3,000", "distanceMeters", 300),
                Map.of("storeName", "매장4", "menu1", "메뉴4", "price1", "4,000", "distanceMeters", 400),
                Map.of("storeName", "매장5", "menu1", "메뉴5", "price1", "5,000", "distanceMeters", 500)
        ));

        assertThat(route).contains("1. 매장1", "2. 매장2", "3. 매장3", "4. 매장4");
        assertThat(route).doesNotContain("5. 매장5");
    }

    @Test
    void localRoutePreservesTheTodaysPickMatchedSecondaryMenuAndItsPrice() {
        GeminiService service = new GeminiService("", 1_000, false);
        var route = service.getRouteRecommendation(List.of(Map.of(
                "storeName", "천이오겹살", "menu1", "삼겹살", "price1", "10,000",
                "menu2", "비빔국수", "price2", "4,000", "matchedMenu", "비빔국수", "distanceMeters", 100)));
        assertThat(route).contains("비빔국수", "4,000원").doesNotContain("삼겹살", "10,000원");
    }

    @Test
    void localChatFallbackUsesOnlyVerifiedStoresAndHonorsBudgetAndCount() {
        GeminiService service = new GeminiService("", 1_000, false);

        String response = fallbackText(service, "만원 이하 점심 두 곳", List.of(
                Map.of("storeId", "a", "storeName", "가까운 식당", "menu1", "백반", "price1", "8,000원", "distanceMeters", 100),
                Map.of("storeId", "b", "storeName", "예산초과 식당", "menu1", "불고기", "price1", "15,000", "distanceMeters", 120),
                Map.of("storeId", "c", "storeName", "두번째 식당", "menu1", "칼국수", "price1", "7,000", "distanceMeters", 300)));

        assertThat(response).contains("가까운 식당", "두번째 식당", "8,000원", "7,000원");
        assertThat(response).doesNotContain("예산초과 식당", "원원");
    }

    @Test
    void localChatFallbackDoesNotRelaxBudgetWhenNoMenuMatches() {
        GeminiService service = new GeminiService("", 1_000, false);

        String response = fallbackText(service, "천원 이하 한 곳", List.of(
                Map.of("storeId", "real", "storeName", "실제 매장", "menu1", "국수", "price1", "5,000", "distanceMeters", 80)));

        assertThat(response).contains("조건을 모두 만족하는 매장을 찾지 못했어요");
        assertThat(response).doesNotContain("실제 매장", "5,000원");
    }

    @Test
    void localChatFallbackUsesSecondaryMenuAndSkipsNonFoodForLunch() {
        GeminiService service = new GeminiService("", 1_000, false);

        List<Map<String, Object>> picks = service.verifiedRecommendations(
                "만원 이하 점심 한 곳", List.of(
                        Map.of(
                                "storeId", "hair",
                                "storeName", "동네미용실",
                                "industry", "미용",
                                "menu1", "커트",
                                "price1", "8,000",
                                "distanceMeters", 50),
                        Map.of(
                                "storeId", "meal",
                                "storeName", "착한식당",
                                "industry", "한식",
                                "menu1", "불고기",
                                "price1", "15,000",
                                "menu2", "백반",
                                "price2", "9,000",
                                "distanceMeters", 200)),
                RecommendationRadius.DEFAULT_METERS);
        String text = service.verifiedRecommendationText(picks, RecommendationRadius.DEFAULT_METERS, true);

        assertThat(text).contains("착한식당", "백반", "9,000원");
        assertThat(text).doesNotContain("동네미용실", "불고기");
        assertThat(picks).extracting(store -> store.get("storeId")).containsExactly("meal");
    }

    /** AiController가 외부 AI 장애 때 쓰는 대체 답변 경로를 그대로 호출합니다. */
    private static String fallbackText(GeminiService service, String message,
                                       List<Map<String, Object>> nearbyStores) {
        List<Map<String, Object>> picks = service.verifiedRecommendations(
                message, nearbyStores, RecommendationRadius.DEFAULT_METERS);
        return service.verifiedRecommendationText(picks, RecommendationRadius.DEFAULT_METERS, true);
    }

    @Test
    void soupMatchesTheActualMenuNotTheNameAndDoesNotFillMissingResults() {
        GeminiService service = new GeminiService("", 1_000, false);
        var result = service.verifiedRecommendations("비 오는 날 국물 추천 세 곳", List.of(
                Map.of("storeId", "a", "storeName", "국물맛집", "menu1", "김밥", "price1", "3000", "distanceMeters", 200),
                Map.of("storeId", "b", "storeName", "식당", "menu1", "김밥", "price1", "3000",
                        "menu2", "칼국수", "price2", "5000", "distanceMeters", 300),
                Map.of("storeId", "c", "storeName", "맛집", "menu1", "국밥", "price1", "5000", "distanceMeters", 3001)), 3000);
        assertThat(result).hasSize(1);
        assertThat(result.get(0)).containsEntry("storeId", "b").containsEntry("matchedMenu", "칼국수")
                .containsEntry("menuIndex", 2);
    }

    @Test
    void mealRequestRejectsDrinksButKeepsCafeFoodAndExplicitCoffeeRequests() {
        GeminiService service = new GeminiService("", 1_000, false);
        var stores = List.of(
                Map.<String, Object>of("storeId", "coffee", "storeName", "가까운 카페", "industry", "카페",
                        "menu1", "아메리카노(HOT)", "price1", "1500", "distanceMeters", 50),
                Map.<String, Object>of("storeId", "branded-drink", "storeName", "커피 매장", "industry", "음식점 · 카페",
                        "menu1", "메가리카노", "price1", "3000", "distanceMeters", 55),
                Map.<String, Object>of("storeId", "cafe-food", "storeName", "카페 식사", "industry", "카페",
                        "menu1", "카페라떼", "price1", "2000", "menu2", "샌드위치", "price2", "5000", "distanceMeters", 100),
                Map.<String, Object>of("storeId", "meal", "storeName", "식당", "industry", "한식",
                        "menu1", "칼국수", "price1", "7000", "distanceMeters", 200));
        for (String message : List.of("10,000원 이하 점심", "저녁 식사", "아침 추천")) {
            var results = service.verifiedRecommendations(message, stores, 3000);
            assertThat(results).extracting(item -> item.get("matchedMenu"))
                    .containsExactly("샌드위치", "칼국수");
        }
        var coffee = service.verifiedRecommendations("점심 후 커피 한 곳", stores, 3000);
        assertThat(coffee).hasSize(1);
        assertThat(coffee.get(0)).containsEntry("storeId", "coffee");
    }

    @Test
    void rainySoupRequestSkipsColdNoodlesAndFriedPorkButKeepsRealSoups() {
        GeminiService service = new GeminiService("", 1_000, false);
        var result = service.verifiedRecommendations("비 오는 날 국물 추천 네 곳", List.of(
                Map.of("storeId", "kong", "storeName", "여름별미", "menu1", "콩국수", "price1", "8000", "distanceMeters", 100),
                Map.of("storeId", "chinese", "storeName", "중화요리", "menu1", "탕수육", "price1", "9000", "distanceMeters", 150),
                Map.of("storeId", "makguksu", "storeName", "춘천집", "menu1", "막국수", "price1", "8000", "distanceMeters", 170),
                Map.of("storeId", "kalguksu", "storeName", "칼국수집", "menu1", "칼국수", "price1", "7000", "distanceMeters", 200),
                Map.of("storeId", "naengi", "storeName", "봄나물식당", "menu1", "냉이된장국", "price1", "7000", "distanceMeters", 250),
                Map.of("storeId", "stew", "storeName", "백반집", "menu1", "김치찌개", "price1", "8000", "distanceMeters", 300)), 3000);

        assertThat(result).extracting(item -> item.get("storeId"))
                .containsExactly("kalguksu", "naengi", "stew");
    }

    @Test
    void radiusOneThreeAndFifteenKmAreHardBoundariesIncludingExactEdge() {
        GeminiService service = new GeminiService("", 1_000, false);
        for (int radius : List.of(1000, 3000, 15000)) {
            var result = service.verifiedRecommendations("추천 두 곳", List.of(
                    Map.of("storeId", "edge", "storeName", "경계", "menu1", "백반", "price1", "5000", "distanceMeters", radius),
                    Map.of("storeId", "outside", "storeName", "외부", "menu1", "백반", "price1", "5000", "distanceMeters", radius + 0.01)), radius);
            assertThat(result).hasSize(1);
            assertThat(result.get(0)).containsEntry("storeId", "edge");
        }
    }

    @Test
    void unknownDistanceMissingIdentityClosedAndUnflaggedZeroCannotBeRecommended() {
        GeminiService service = new GeminiService("", 1_000, false);
        assertThat(service.verifiedRecommendations("추천", List.of(
                Map.of("storeName", "ID 없음", "menu1", "백반", "price1", "5000", "distanceMeters", 100),
                Map.of("storeId", "unknown", "storeName", "거리 없음", "menu1", "백반", "price1", "5000"),
                Map.of("storeId", "closed", "storeName", "폐업", "menu1", "백반", "price1", "5000", "distanceMeters", 100, "closed", true),
                Map.of("storeId", "zero", "storeName", "근거 없음", "menu1", "백반", "price1", "0", "distanceMeters", 100)), 3000)).isEmpty();
    }

    @Test
    void explicitFreeAndMultiplePricesPreserveTheirMeaning() {
        GeminiService service = new GeminiService("", 1_000, false);
        var result = service.verifiedRecommendations("4000원 이하 추천 두 곳", List.of(
                Map.of("storeId", "free", "storeName", "무료", "menu1", "무료 서비스", "price1", "0", "free1", true, "distanceMeters", 100),
                Map.of("storeId", "multi", "storeName", "선택", "menu1", "김밥", "price1", "3,000 / 3,500", "distanceMeters", 200),
                Map.of("storeId", "range", "storeName", "예산초과선택", "menu1", "백반", "price1", "3000~5000", "distanceMeters", 150)), 3000);
        assertThat(result).hasSize(2);
        assertThat(result.get(0)).containsEntry("free", true).containsEntry("minimumPrice", 0L);
        assertThat(result.get(1)).containsEntry("rawPrice", "3,000 / 3,500")
                .containsEntry("minimumPrice", 3000L).containsEntry("maximumPrice", 3500L)
                .containsEntry("priceExact", false);
        assertThat(service.verifiedRecommendationText(result, 3000, false))
                .contains("무료", "3,000 / 3,500원").doesNotContain("30,003,500");
    }
}
