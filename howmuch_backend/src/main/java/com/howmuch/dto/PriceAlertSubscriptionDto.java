package com.howmuch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 사용자의 매장별 가격 알림 구독 상태.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PriceAlertSubscriptionDto {
    private String storeId;
    private String storeName;
    private String menuName;
    private String price;
    private boolean enabled;
    private boolean notifyOnRise;
    private boolean notifyOnDrop;
    private boolean notifyOnNewMenu;
}
