package com.howmuch.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;
import java.util.List;

@Data
public class PriceAlertBatchRequest {
    @NotNull @Valid @Size(max = 400)
    private List<StorePreference> stores;
    @NotNull private Boolean notifyOnRise;
    @NotNull private Boolean notifyOnDrop;
    @NotNull private Boolean notifyOnNewMenu;

    @Data
    public static class StorePreference {
        @NotBlank @Size(max = 512) private String storeId;
        @NotNull private Boolean enabled;
    }
}
