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

        assertThat(route).contains("2,000원", "5,000원");
        assertThat(route).doesNotContain("원원", "5000원");
    }

    @Test
    void routeFallsBackWhenAiRouteIsEnabledWithoutAKey() {
        GeminiService service = new GeminiService("", 1_000, true);

        String route = service.getRouteRecommendation(List.of(
                Map.of("storeName", "먼 매장", "menu1", "국수", "price1", "5,000", "distanceMeters", 500),
                Map.of("storeName", "가까운 매장", "menu1", "김밥", "price1", "3,000", "distanceMeters", 100)));

        assertThat(route).contains("가까운 매장", "거리순으로 추천 루트");
        // The picks are already in route order; the text does not re-sort them.
        assertThat(route.indexOf("먼 매장")).isLessThan(route.indexOf("가까운 매장"));
    }

    /** QA 2026-10-07 #6, #27: older app builds show this text under the route cards. */
    @Test
    void localRouteKeepsTheRouteOrderOfPicksWithTheUsualWonFormat() {
        GeminiService service = new GeminiService("", 1_000, false);

        // Route order from FirebaseService.orderRouteStops, not straight distance.
        String route = service.getRouteRecommendation(List.of(
                Map.of("storeName", "온밥", "menu1", "제육덮밥", "price1", "7500", "distanceMeters", 900),
                Map.of("storeName", "등촌샤브칼국수", "menu1", "버섯칼국수", "price1", "9000~10000",
                        "distanceMeters", 100),
                Map.of("storeName", "아콘스톨", "menu1", "김밥", "price1", "0", "free1", true,
                        "distanceMeters", 400)));

        assertThat(route).startsWith("현재는 거리순으로");
        assertThat(route.lines().skip(1).toList()).containsExactly(
                "1. 온밥 (제육덮밥, 7,500원)",
                "2. 등촌샤브칼국수 (버섯칼국수, 9,000 ~ 10,000원)",
                "3. 아콘스톨 (김밥, 무료)");
        assertThat(route).doesNotContain("가까운 순서");
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

    /** QA 10/7 #1: 질문 칩 '혼밥 분식 추천'이 가까운 증명사진관·삼겹살집을 '조건을 만족한다'며 추천했다. */
    @Test
    void bunsikQuickPromptRecommendsOnlyBunsikMenusAndSaysWhenFewerThanThreeMatch() {
        GeminiService service = new GeminiService("", 1_000, false);
        var stores = List.<Map<String, Object>>of(
                Map.of("storeId", "photo", "storeName", "어텐션픽스튜디오", "industry", "기타비요식업",
                        "menu1", "증명사진", "price1", "19000", "distanceMeters", 120, "source", "GOV"),
                Map.of("storeId", "pork", "storeName", "대명꼬기", "industry", "한식",
                        "menu1", "삼겹살", "price1", "7000", "distanceMeters", 504, "source", "GOV"),
                Map.of("storeId", "galbi", "storeName", "명물갈비", "industry", "한식",
                        "menu1", "수제돼지갈비", "price1", "15000", "distanceMeters", 560, "source", "GOV"),
                Map.of("storeId", "stew", "storeName", "백반집", "industry", "한식",
                        "menu1", "김치찌개", "price1", "8000", "distanceMeters", 600, "source", "GOV"),
                Map.of("storeId", "chinese", "storeName", "중화반점", "industry", "중식",
                        "menu1", "우동", "price1", "7000", "distanceMeters", 700, "source", "GOV"),
                Map.of("storeId", "pho", "storeName", "쌀국수집", "industry", "기타요식업",
                        "menu1", "소고기쌀국수", "price1", "9000", "distanceMeters", 800, "source", "GOV"),
                Map.of("storeId", "kimbap", "storeName", "김밥천국", "industry", "한식",
                        "menu1", "김치찌개", "price1", "7000", "menu2", "김밥", "price2", "3500",
                        "distanceMeters", 1478, "source", "GOV"));

        var result = service.verifiedRecommendations("혼밥 분식 추천", stores, 3000);

        assertThat(result).extracting(item -> item.get("storeId")).containsExactly("kimbap");
        assertThat(result.get(0)).containsEntry("matchedMenu", "김밥").containsEntry("menuIndex", 2);
        assertThat(service.verifiedRecommendationText("혼밥 분식 추천", result, 3000, false))
                .contains("조건을 만족하는 1곳", "조건에 맞는 매장이 부족해 다른 매장으로 채우지 않았어요",
                        "1. 김밥천국 — 김밥 · 3,500원 · 약 1.5km · 정부 인증")
                .doesNotContain("어텐션픽스튜디오", "대명꼬기", "명물갈비", "1478m");
        // 한 곳만 원했으면 찾은 1곳으로 충분하므로 부족 안내를 붙이지 않는다.
        assertThat(service.verifiedRecommendationText("분식 한 곳 추천", result, 3000, false))
                .contains("김밥천국").doesNotContain("채우지 않았어요");
    }

    /** 앱이 제안하는 질문 칩은 모두 음식점이 아닌 가까운 매장을 고르지 않는다. 생활 서비스 요청은 그대로다. */
    @Test
    void quickPromptsSkipNonFoodBusinessesWhileServiceRequestsStillWork() {
        GeminiService service = new GeminiService("", 1_000, false);
        var stores = List.<Map<String, Object>>of(
                Map.of("storeId", "photo", "storeName", "사진관", "industry", "기타비요식업",
                        "menu1", "여권사진", "price1", "8000", "distanceMeters", 50),
                Map.of("storeId", "barber", "storeName", "이발소", "industry", "이용업",
                        "menu1", "커트", "price1", "8000", "distanceMeters", 60),
                Map.of("storeId", "mislabeled", "storeName", "업종이 이용업인 매장", "industry", "이용업",
                        "menu1", "김치찌개", "price1", "7000", "distanceMeters", 70),
                Map.of("storeId", "hair", "storeName", "제보 미용실", "industry", "생활서비스 · 미용실",
                        "menu1", "커트", "price1", "9000", "distanceMeters", 80),
                Map.of("storeId", "cafe", "storeName", "동네카페", "industry", "카페",
                        "menu1", "아메리카노", "price1", "2000", "distanceMeters", 200),
                Map.of("storeId", "noodle", "storeName", "칼국수집", "industry", "한식",
                        "menu1", "칼국수", "price1", "7000", "distanceMeters", 300));
        Map<String, List<String>> expected = Map.of(
                "10,000원 이하 점심", List.of("noodle"),
                "비 오는 날 국물", List.of("noodle"),
                "혼밥 분식 추천", List.of("noodle"),
                "근처 오후 코스", List.of("cafe", "noodle"),
                "미용실 추천", List.of("hair"));

        expected.forEach((prompt, ids) -> assertThat(service.verifiedRecommendations(prompt, stores, 3000))
                .as(prompt).extracting(item -> item.get("storeId")).containsExactlyElementsOf(ids));
    }

    /** QA 10/7 #27: AI 답변도 다른 화면처럼 7,000원·약 1.5km로 쓴다. */
    @Test
    void chatAnswerWritesPricesWithCommasAndLongDistancesInKilometres() {
        GeminiService service = new GeminiService("", 1_000, false);
        var result = service.verifiedRecommendations("추천 네 곳", List.of(
                Map.of("storeId", "a", "storeName", "가까운 식당", "menu1", "백반", "price1", "7000", "distanceMeters", 504),
                Map.of("storeId", "b", "storeName", "경계 식당", "menu1", "백반", "price1", "10000", "distanceMeters", 999.6),
                Map.of("storeId", "c", "storeName", "먼 식당", "menu1", "백반", "price1", "8000원", "distanceMeters", 1478),
                Map.of("storeId", "d", "storeName", "선택 식당", "menu1", "백반", "price1", "3000~5000", "distanceMeters", 2950)),
                3000);

        assertThat(service.verifiedRecommendationText(result, 3000, false))
                .contains("가까운 식당 — 백반 · 7,000원 · 약 504m", "경계 식당 — 백반 · 10,000원 · 약 1.0km",
                        "먼 식당 — 백반 · 8,000원 · 약 1.5km", "선택 식당 — 백반 · 3,000 ~ 5,000원 · 약 3.0km")
                .doesNotContain("7000원", "10000원", "1478m", "원원");
    }

    /** test/ai_shared_rules_test.dart의 'menu intent follows the server rules' 표와 같은 행이다. */
    @Test
    void menuIntentTableMatchesTheAppMirror() {
        GeminiService service = new GeminiService("", 1_000, false);
        Object[][] table = {
                {"칼국수", "혼밥 분식 추천", "한식", true},
                {"김밥", "혼밥 분식 추천", "한식", true},
                {"떡볶이", "혼밥 분식 추천", "기타요식업", true},
                {"김치찌개", "혼밥 분식 추천", "음식점 · 분식", true},
                {"김치찌개", "혼밥 분식 추천", "한식", false},
                {"삼겹살", "혼밥 분식 추천", "한식", false},
                {"수제돼지갈비", "혼밥 분식 추천", "한식", false},
                {"증명사진", "혼밥 분식 추천", "기타비요식업", false},
                {"순대국", "혼밥 분식 추천", "한식", false},
                {"소고기쌀국수", "혼밥 분식 추천", "기타요식업", false},
                {"우동", "혼밥 분식 추천", "중식", false},
                {"짜장면", "중식 추천", "중식", true},
                {"김치찌개", "중식 추천", "한식", false},
                {"짜장면", "중화역 근처 점심", "한식", true},
                {"라면", "혼밥 분식 추천", "음식점 · 치킨", false},
                {"증명사진", "10,000원 이하 점심", "기타비요식업", false},
                {"커트", "10,000원 이하 점심", "이용업", false},
                {"김치찌개", "비 오는 날 국물", "이용업", false},
                {"여권사진", "근처 오후 코스", "기타비요식업", false},
                {"아메리카노", "근처 오후 코스", "카페", true},
                {"바지락칼국수", "비 오는 날 국물", "한식", true},
                {"김밥", "비 오는 날 국물", "분식", false},
                {"비빔국수", "비 오는 날 국물", "한식", false},
                {"짜장면", "칼국수 추천", "중식", false},
                {"아메리카노", "점심 후 커피", "카페", true},
                {"칼국수", "점심 후 커피", "한식", false},
                {"유자차", "점심 추천", "카페", false},
                {"메가리카노", "저녁 식사", "음식점 · 카페", false},
                {"샌드위치", "점심 추천", "카페", true},
                {"커트", "점심 추천", "미용", false},
                {"커트", "미용실 추천", "미용", true},
                {"커트", "미용실 추천", "생활서비스 · 미용실", true},
                {"드라이클리닝", "미용 추천", "세탁", false},
        };
        for (Object[] row : table) {
            assertThat(service.menuMatchesIntent((String) row[1], (String) row[0], Map.of("industry", row[2])))
                    .as(row[1] + " → " + row[0] + " (" + row[2] + ")")
                    .isEqualTo(row[3]);
        }
    }
}
