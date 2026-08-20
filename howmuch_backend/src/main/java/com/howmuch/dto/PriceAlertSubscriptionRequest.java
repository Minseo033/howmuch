package com.howmuch.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 매장별 가격 알림 구독 상태 변경 요청.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class PriceAlertSubscriptionRequest {
    @NotBlank
    @Size(max = 200)
    private String storeId;

    @NotNull
    private Boolean enabled;

    private Boolean notifyOnRise;
    private Boolean notifyOnDrop;
    private Boolean notifyOnNewMenu;
}
