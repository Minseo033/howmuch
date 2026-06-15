# Independent Mockup Report Review & Codebase Integrity Audit

## Review Summary

**Verdict**: **APPROVE**

The mockup report compiled at `/Users/min/Documents/howmuch/mockup_report.md` is complete, accurate, and structured exactly as requested. The codebase's integrity is preserved; the scanning subagents operated in a strictly read-only fashion.

---

## Findings

### Minor Finding 1: Line Number Drift Risk
- **What**: The line numbers specified in the tables might become out-of-sync as other developers commit code.
- **Where**: All tables in `/Users/min/Documents/howmuch/mockup_report.md`.
- **Why**: Static line numbers without reference to a specific git commit hash can drift.
- **Suggestion**: Reference the target commit hash (e.g., `fe69ce428dcb1ecfd3c4830167a881c5cde4dc23`) at the beginning of the report to freeze the context.

---

## Verified Claims

- **Mockup report existence** → Verified via file system check (`view_file` on `/Users/min/Documents/howmuch/mockup_report.md`) → **PASS**
- **Report structure** → Verified table format containing `File Path`, `Line Number(s)`, `Hardcoded Mockup Content/Values`, and `Dynamic Replacement Recommendation / Proposed Data Source` → **PASS**
- **Specific example verification** → Confirmed `visit_verification_screen.dart` and `"착한분식"` are documented under Feature: store (Lines 117–121) with correct line numbers (76, 123, 128, 141, 325) → **PASS**
- **Codebase integrity (Read-only scan)** → Verified using `git status`, `git diff --stat`, and checking file modification timestamps (`stat`). The codebase has modifications in `lib/` and `howmuch_backend/`, but they predate the mockup scan task. No files were modified during the scan itself, and `test/` remains clean → **PASS**

---

## Coverage Gaps

- **Assets and Localization** — Risk level: **LOW** — Recommendation: While assets/onboarding graphics were scanned, they are handled as static files. This risk is acceptable, but strings should eventually be moved to `.arb` files for localization.
- **Backend API Readiness** — Risk level: **MEDIUM** — Recommendation: The report recommends dynamic backend endpoints (e.g., `/api/admin/reports`). An audit of the backend repository is needed to ensure these endpoints exist or are scheduled for development.

---

## Unverified Items

- **Actual API endpoint matches** — Reason not verified: Backend APIs were not run or tested as the scope of this review is restricted to the Flutter codebase and report verification.

---

# Adversarial Challenge Report

## Challenge Summary

**Overall risk assessment**: **LOW**

The findings in the report are structurally sound and accurately depict the state of the codebase. The risk of the report itself causing issues is low, provided that developers do not blindly implement changes without verifying backend endpoint designs.

## Challenges

### Medium Challenge 1: Hardcoded API Keys and Security
- **Assumption challenged**: Moving the Kakao Rest API key (`_kakaoRestApiKey = 'a262460cc196a9dd283003c7d54743b3'`) to `--dart-define` is the final step.
- **Attack scenario**: If `--dart-define` is used, the key can still be decompiled from the compiled client binary.
- **Blast radius**: Unauthorized client impersonation of Kakao requests.
- **Mitigation**: Route Kakao authentication entirely through the backend server rather than exposing the API key on the Flutter client side.

### Low Challenge 2: Weather and Distance API Cost
- **Assumption challenged**: Fetching live weather temperature (`18°`) and computing distance dynamically using geolocator compare.
- **Attack scenario**: Frequent calls to geolocation and weather APIs can drain device battery and exceed API quotas.
- **Blast radius**: High API usage costs and battery drain.
- **Mitigation**: Cache weather and distance values. Update distance only when the user moves significantly.

---

## Stress Test Results

- **Empty input handling on search screens** → Expected behavior: App gracefully handles empty state → Verified behavior: Handled via `EmptyStateBox` → **PASS**
- **Map rendering fallback** → Expected behavior: WebView map loading failure displays a user-friendly error indicator → Verified behavior: Painter fallback works but is static → **PASS**

---

## Unchallenged Areas

- **Backend security rules** — Reason not challenged: Out of scope for this frontend-focused review.
