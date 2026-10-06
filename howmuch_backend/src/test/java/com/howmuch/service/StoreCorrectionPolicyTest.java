package com.howmuch.service;

import com.howmuch.dto.ReportApprovalRequest;
import java.util.Map;
import java.util.HashMap;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class StoreCorrectionPolicyTest {
    private final Map<String, Object> store = Map.of("storeId", "store_a", "menu1", "국밥", "price1", "6000",
            "free1", false, "address", "서울 중구", "latitude", 37.5, "longitude", 127.0, "correctionRevision", 0L);
    private final Map<String, Object> info = Map.of("reportType", "STORE_INFO", "changeType", "other");

    private ReportApprovalRequest approval(String resolution, Map<String, Object> after) {
        var request = new ReportApprovalRequest(); request.setResolution(resolution);
        request.setReviewReason("자료와 변경 전후 내용 확인"); request.setExpectedRevision(0L);
        request.setBefore(store); request.setAfter(after); return request;
    }

    @Test void appliesOnlyReviewedPriceFieldsAndPreservesRawOriginal() {
        var decision = StoreCorrectionPolicy.decide(info, store, approval("PRICE", Map.of(
                "menuSlot", 1, "menu", "국밥", "price", "6,500", "free", false, "source", "USER")));
        assertThat(decision.fields()).containsEntry("price1", "6500").doesNotContainKey("source");
        assertThat(store).containsEntry("price1", "6000");
    }
    @Test void requiresExplicitFreeForZeroAndRejectsFreePositive() {
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, store, approval("PRICE", Map.of(
                "menuSlot", 1, "menu", "국밥", "price", "0", "free", false)))).isInstanceOf(IllegalArgumentException.class);
        assertThat(StoreCorrectionPolicy.decide(info, store, approval("PRICE", Map.of(
                "menuSlot", 1, "menu", "무료 국밥", "price", "0", "free", true))).fields()).containsEntry("free1", true);
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, store, approval("PRICE", Map.of(
                "menuSlot", 1, "menu", "국밥", "price", "6000", "free", true)))).isInstanceOf(IllegalArgumentException.class);
    }
    @Test void refusesMultipleAmountsAsAnActualReviewedPrice() {
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, store, approval("PRICE", Map.of(
                "menuSlot", 1, "menu", "국밥", "price", "3000 / 3500")))).isInstanceOf(IllegalArgumentException.class);
    }
    @Test void rejectsStaleRevisionAndChangedBeforeValues() {
        var stale = approval("CLOSED", Map.of("isClosed", true)); stale.setExpectedRevision(1L);
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, store, stale)).isInstanceOf(IllegalStateException.class);
        var changed = approval("CLOSED", Map.of("isClosed", true)); changed.setBefore(Map.of("price1", "6500"));
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, store, changed)).isInstanceOf(IllegalStateException.class);
    }
    @Test void noChangeRequiresReasonAndDoesNotModifyAnything() {
        assertThat(StoreCorrectionPolicy.decide(info, store, approval("NO_CHANGE", Map.of())).fields()).isEmpty();
        var noReason = approval("NO_CHANGE", Map.of()); noReason.setReviewReason(" ");
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, store, noReason)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, store, null)).isInstanceOf(IllegalArgumentException.class);
    }
    @Test void locationRequiresActualCoordinatesAndReviewedBefore() {
        assertThat(StoreCorrectionPolicy.decide(info, store, approval("LOCATION", Map.of(
                "address", "서울 종로구", "latitude", 37.6, "longitude", 127.1))).fields())
                .containsEntry("address", "서울 종로구");
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, store, approval("LOCATION", Map.of(
                "address", "서울", "latitude", "NaN", "longitude", 127.1)))).isInstanceOf(IllegalArgumentException.class);
    }
    @Test void ordinaryPriceUsesMatchingMenuAndRejectsWrongDirection() {
        var report = Map.<String, Object>of("changeType", "drop", "menu1", "국밥", "price1", "5500");
        assertThat(StoreCorrectionPolicy.decide(report, store, null).fields()).containsEntry("price1", "5500");
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(Map.of("changeType", "rise", "menu1", "국밥", "price1", "5500"), store, null))
                .isInstanceOf(IllegalStateException.class);
    }
    @Test void legacyZeroNeverBecomesFreeAutomatically() {
        assertThatThrownBy(() -> StoreCorrectionPolicy.validateNewStorePrices(Map.of("menu1", "백반", "price1", "0")))
                .isInstanceOf(IllegalArgumentException.class);
        StoreCorrectionPolicy.validateNewStorePrices(Map.of("menu1", "무료 식사", "price1", "0", "free1", true));
    }

    @Test void refusesRenamingToAnotherRegisteredMenu() {
        var twoMenus = new HashMap<>(store); twoMenus.put("menu2", "김밥"); twoMenus.put("price2", "3000");
        var request = approval("PRICE", Map.of("menuSlot", 1, "menu", "김밥", "price", "3500", "free", false));
        request.setBefore(twoMenus);
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, twoMenus, request))
                .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("이미 등록");
    }

    @Test void refusesToApproveACorrectionThatChangesNothing() {
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, store, approval("PRICE", Map.of(
                "menuSlot", 1, "menu", "국밥", "price", "6,000원", "free", false))))
                .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("변경 없음");
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, store, approval("LOCATION", Map.of(
                "address", "서울 중구", "latitude", 37.5, "longitude", 127.0))))
                .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("변경 없음");
        var closed = new HashMap<String, Object>(store); closed.put("isClosed", true);
        var closeAgain = approval("CLOSED", Map.of("isClosed", true)); closeAgain.setBefore(closed);
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, closed, closeAgain))
                .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("변경 없음");
        // Renaming the menu at the same price is still a real change.
        assertThat(StoreCorrectionPolicy.decide(info, store, approval("PRICE", Map.of(
                "menuSlot", 1, "menu", "순대국밥", "price", "6000", "free", false))).fields())
                .containsEntry("menu1", "순대국밥");
    }

    @Test void locationMustStayInsideKorea() {
        // Swapped latitude and longitude is the typical review mistake.
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, store, approval("LOCATION", Map.of(
                "address", "서울 종로구", "latitude", 127.1, "longitude", 37.6))))
                .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("국내 좌표");
        assertThatThrownBy(() -> StoreCorrectionPolicy.decide(info, store, approval("LOCATION", Map.of(
                "address", "도쿄", "latitude", 35.68, "longitude", 139.76))))
                .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("국내 좌표");
        assertThat(StoreCorrectionPolicy.decide(info, store, approval("LOCATION", Map.of(
                "address", "제주 서귀포시 대정읍 마라로", "latitude", 33.12, "longitude", 126.27))).fields())
                .containsEntry("latitude", 33.12);
    }
}
