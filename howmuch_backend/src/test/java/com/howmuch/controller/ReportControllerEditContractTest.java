package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.UserReportRequest;
import com.howmuch.service.FirebaseService;
import com.howmuch.service.KakaoLocalService;
import com.howmuch.service.SimpleRateLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** 계약 C7: 수정 요청은 기존 제보의 유형으로 검증되고, 유형·대상 변경은 400입니다. */
class ReportControllerEditContractTest {
    private final FirebaseService firebaseService = mock(FirebaseService.class);
    private final ReportController controller = new ReportController(
            firebaseService, mock(KakaoLocalService.class), mock(SimpleRateLimiter.class));
    private final MockHttpServletRequest request = new MockHttpServletRequest();

    @BeforeEach
    void setUp() throws Exception {
        request.setAttribute(SessionAuthFilter.UID_ATTRIBUTE, "user-1");
        when(firebaseService.getOwnedReportForEdit("report-1", "user-1")).thenReturn(Map.of(
                "reporterId", "user-1", "status", "PENDING", "storeId", "store_a", "storeName", "국밥집",
                "changeType", "rise", "description", "메뉴판 가격이 올랐어요"));
        when(firebaseService.getCurrentMenuPrice("store_a", "국밥집", "국밥")).thenReturn("8000");
    }

    @Test
    void priceChangeEditIsValidatedAsAPriceChangeEvenWhenTheFormOmitsItsType() throws Exception {
        UserReportRequest edit = generalFormEdit();

        ResponseEntity<?> response = controller.updateStoreReport("report-1", request, edit);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(String.valueOf(((Map<?, ?>) response.getBody()).get("message"))).contains("메뉴판 가격 확인");
        verify(firebaseService, never()).updateUserReport(anyString(), anyString(), any());
    }

    @Test
    void validPriceChangeEditKeepsItsTypeTargetAndDescription() throws Exception {
        UserReportRequest edit = generalFormEdit();
        edit.setCheckedMenuPrice(true);

        ResponseEntity<?> response = controller.updateStoreReport("report-1", request, edit);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        ArgumentCaptor<UserReportRequest> saved = ArgumentCaptor.forClass(UserReportRequest.class);
        verify(firebaseService).updateUserReport(eq("report-1"), eq("user-1"), saved.capture());
        assertThat(saved.getValue().getChangeType()).isEqualTo("rise");
        assertThat(saved.getValue().getStoreId()).isEqualTo("store_a");
        assertThat(saved.getValue().getDescription()).isEqualTo("메뉴판 가격이 올랐어요");
    }

    @Test
    void changingTheTypeOrTargetReturnsBadRequestWithoutSaving() throws Exception {
        UserReportRequest changedType = generalFormEdit();
        changedType.setCheckedMenuPrice(true);
        changedType.setChangeType("drop");
        UserReportRequest changedStore = generalFormEdit();
        changedStore.setCheckedMenuPrice(true);
        changedStore.setStoreId("store_b");

        assertThat(controller.updateStoreReport("report-1", request, changedType).getStatusCode())
                .isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(controller.updateStoreReport("report-1", request, changedStore).getStatusCode())
                .isEqualTo(HttpStatus.BAD_REQUEST);
        verify(firebaseService, never()).updateUserReport(anyString(), anyString(), any());
    }

    private UserReportRequest generalFormEdit() {
        UserReportRequest edit = new UserReportRequest();
        edit.setStoreName("국밥집");
        edit.setAddress("서울 중구");
        edit.setMenu1("국밥");
        edit.setPrice1("9000");
        return edit;
    }
}

