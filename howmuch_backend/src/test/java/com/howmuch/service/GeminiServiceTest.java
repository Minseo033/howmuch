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
    void localChatFallbackUsesOnlyVerifiedStoresAndHonorsBudgetAndCount() {
        GeminiService service = new GeminiService("", 1_000, false);

        String response = service.buildLocalChatRecommendation("만원 이하 점심 두 곳", List.of(
                Map.of("storeId", "a", "storeName", "가까운 식당", "menu1", "백반", "price1", "8,000원", "distanceMeters", 100),
                Map.of("storeId", "b", "storeName", "예산초과 식당", "menu1", "불고기", "price1", "15,000", "distanceMeters", 120),
                Map.of("storeId", "c", "storeName", "두번째 식당", "menu1", "칼국수", "price1", "7,000", "distanceMeters", 300))).text();

        assertThat(response).contains("가까운 식당", "두번째 식당", "8,000원", "7,000원");
        assertThat(response).doesNotContain("예산초과 식당", "원원");
    }

    @Test
    void localChatFallbackUsesRealAlternativesWhenBudgetHasNoMatch() {
        GeminiService service = new GeminiService("", 1_000, false);

        String response = service.buildLocalChatRecommendation("천원 이하 한 곳", List.of(
                Map.of("storeId", "real", "storeName", "실제 매장", "menu1", "국수", "price1", "5,000", "distanceMeters", 80))).text();

        assertThat(response).contains("실제 매장 대안", "실제 매장", "5,000원");
    }

    @Test
    void localChatFallbackUsesSecondaryMenuAndSkipsNonFoodForLunch() {
        GeminiService service = new GeminiService("", 1_000, false);

        GeminiService.LocalChatRecommendation result = service.buildLocalChatRecommendation(
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
                                "distanceMeters", 200)));

        assertThat(result.text()).contains("착한식당", "백반", "9,000원");
        assertThat(result.text()).doesNotContain("동네미용실", "불고기");
        assertThat(result.storeIds()).containsExactly("meal");
    }
}
