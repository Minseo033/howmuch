package com.howmuch.service;

import org.junit.jupiter.api.Test;
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
}
