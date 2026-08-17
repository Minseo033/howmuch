package com.howmuch.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NotificationSettingsDto {
    @NotNull
    private Boolean all;
    @NotNull
    private Boolean review;
    @NotNull
    private Boolean report;
    @NotNull
    private Boolean price;
    @NotNull
    private Boolean todayPick;
    @NotNull
    private Boolean quietHours;

    @NotBlank
    @Pattern(regexp = "(?:[01]\\d|2[0-3]):[0-5]\\d")
    private String quietStart;

    @NotBlank
    @Pattern(regexp = "(?:[01]\\d|2[0-3]):[0-5]\\d")
    private String quietEnd;
}
