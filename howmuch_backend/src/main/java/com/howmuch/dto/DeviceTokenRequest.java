package com.howmuch.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class DeviceTokenRequest {
    @NotBlank
    @Size(max = 4096)
    private String token;

    @NotBlank
    private String platform;
}
