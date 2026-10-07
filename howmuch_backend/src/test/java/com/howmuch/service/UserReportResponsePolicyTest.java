package com.howmuch.service;

import org.junit.jupiter.api.Test;
import java.util.List;
import java.util.Map;
import static org.assertj.core.api.Assertions.assertThat;

class UserReportResponsePolicyTest {
    @Test void ownerGetsPublicResultAndOriginalFieldsButNeverInternalReview() {
        var result = UserReportResponsePolicy.ownerView("r1", Map.of(
            "reportType", "STORE_INFO", "resolution", "NO_CHANGE", "description", "신고 내용",
            "menu4", "음료", "free4", true, "reviewReason", "내부 검토",
            "approvedBy", "admin", "appliedFields", Map.of("price1", "5000"), "baseRevision", 1));
        assertThat(result).containsEntry("id", "r1").containsEntry("resolution", "NO_CHANGE")
            .containsEntry("description", "신고 내용").containsEntry("free4", true)
            .doesNotContainKeys("reviewReason", "approvedBy", "appliedFields", "baseRevision");
    }
    @Test void oldDocumentsKeepMissingResolutionMissingAndRejectReasonReadable() {
        var result = UserReportResponsePolicy.ownerView("old", Map.of("rejectReason", "사진 확인 필요", "status", "REJECTED"));
        assertThat(result).containsEntry("rejectReason", "사진 확인 필요").doesNotContainKey("resolution");
    }
    @Test void approvedPriceChangeAddsOnlyThePreviousPublicPriceOfTheChangedMenu() {
        // QA 2026-10-07 #15: 승인 직전 매장에 공개돼 있던 가격만 더하고 검토 기록은 계속 숨깁니다.
        var result = UserReportResponsePolicy.ownerView("p1", Map.ofEntries(
            Map.entry("status", "APPROVED"), Map.entry("changeType", "rise"), Map.entry("resolution", "PRICE"),
            Map.entry("menu1", "삼겹살(200g)"), Map.entry("price1", "16000"), Map.entry("free1", false),
            Map.entry("previousFields", Map.of("menu3", "삼겹살(200g)", "price3", "15000", "free3", false)),
            Map.entry("appliedFields", Map.of("menu3", "삼겹살(200g)", "price3", "16000", "free3", false)),
            Map.entry("reviewReason", "승인된 가격 변동 제보 반영"), Map.entry("approvedBy", "admin"),
            Map.entry("baseRevision", 2L)));
        assertThat(result).containsEntry("previousPrice", "15000").containsEntry("previousFree", false)
            .containsEntry("price1", "16000").containsEntry("resolution", "PRICE")
            .doesNotContainKeys("previousFields", "appliedFields", "reviewReason", "approvedBy", "baseRevision");
    }
    @Test void aDeletedFreeMenuKeepsItsFreeFlagInThePreviousPrice() {
        var result = UserReportResponsePolicy.ownerView("p2", Map.of("status", "APPROVED", "changeType", "delete",
            "previousFields", Map.of("menu2", "물", "price2", "0", "free2", true)));
        assertThat(result).containsEntry("previousPrice", "0").containsEntry("previousFree", true);
    }
    @Test void previousPriceIsLeftOutWithoutAnApprovedPublicPriceToShow() {
        List<Map<String, Object>> documents = List.of(
            // 신규 메뉴는 비어 있던 칸이라 기존 가격이 없습니다.
            Map.of("status", "APPROVED", "changeType", "new",
                "previousFields", Map.of("menu2", "", "price2", "", "free2", false)),
            // 반영 기록 없이 승인된 옛 제보와 검토 중 제보는 앱이 지금처럼 매장 조회 값을 씁니다.
            Map.of("status", "APPROVED", "changeType", "drop"),
            Map.of("status", "PENDING", "changeType", "rise", "previousFields", Map.of("price1", "15000")),
            // 정보 오류 신고는 가격 변동 제보가 아닙니다.
            Map.of("status", "APPROVED", "reportType", "STORE_INFO", "changeType", "price_mismatch",
                "previousFields", Map.of("menu1", "라면", "price1", "4000", "free1", false)));
        assertThat(documents).allSatisfy(document -> assertThat(UserReportResponsePolicy.ownerView("x", document))
            .doesNotContainKeys("previousPrice", "previousFree", "previousFields"));
    }
}
