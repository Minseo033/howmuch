package com.howmuch.dto;

import java.util.Map;
import lombok.Data;

/** Explicit review payload; never used as an unrestricted catalog patch. */
@Data
public class ReportApprovalRequest {
    private String resolution;
    private String reviewReason;
    private Long expectedRevision;
    private Map<String, Object> before;
    private Map<String, Object> after;
}
