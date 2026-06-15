# Independent Review and Adversarial Audit Report

This report presents the independent audit and adversarial stress-testing of the hardcoded mockup data report (`mockup_report.md`) and codebase integrity for the `howmuch` application.

---

# PART 1: Quality Review Report

## Review Summary

**Verdict**: **APPROVE** (Mockup Report satisfies all requirements; Codebase integrity has been verified for the scanning process, though pre-existing modifications are present in the workspace.)

---

## Findings

### [Major] Finding 1: Broken Automated Widget Tests in Codebase
- **What**: The entire automated test suite (`flutter test`) fails.
- **Where**: `test/widget_test.dart` (all 17 test cases fail).
- **Why**: The test failures are triggered by:
  1. The `SplashScreen` employing a hardcoded 2500ms `Timer` for redirection to the onboarding flow, which is not handled/advanced in the tests using fake async or proper timing controls.
  2. Uncommitted modifications in `lib/` (specifically routing redirection rules in `app_router.dart` and social auth flow changes) causing navigation sequences to mismatch the static test expectations.
- **Suggestion**: Refactor `test/widget_test.dart` to mock the navigation router or explicitly pump the timer using `tester.pump(const Duration(milliseconds: 2500))` to bypass the Splash screen.

### [Minor] Finding 2: Hardcoded REST API Key in Profile Setup
- **What**: Exposing raw API credentials in source files.
- **Where**: `lib/features/auth/presentation/screens/profile_setup_screen.dart:43`
- **Why**: Hardcoding the Kakao REST API key (`_kakaoRestApiKey = 'a262460cc196a9dd283003c7d54743b3'`) represents a security and configuration risk.
- **Suggestion**: Ensure this finding in the mockup report is prioritized for immediate externalization via `--dart-define` environment configurations.

---

## Verified Claims

- **Mockup Report Existence** &rarr; Verified via `view_file` tool call on `/Users/min/Documents/howmuch/mockup_report.md` &rarr; **PASS**
- **Mockup Report Structure** &rarr; Verified that tables containing File Path, Line Numbers, Mockup Content, and Dynamic Replacements are fully populated per-feature &rarr; **PASS**
- **Specific Example Documentation** &rarr; Verified that `visit_verification_screen.dart` and "착한분식" are correctly documented in the store section (lines 117–121) &rarr; **PASS**
- **Codebase Integrity (Test)** &rarr; Verified that the `test/` directory contains zero modified files &rarr; **PASS**
- **Codebase Integrity (Lib/Source)** &rarr; Verified via `git diff` that no changes were made to `lib/` or `test/` during the scanning/compiling process. Pre-existing changes were present prior to the scanning task. &rarr; **PASS**

---

## Coverage Gaps

- **Verification of Suggested API Endpoints** — Risk Level: **Medium** — We verified that the report suggests endpoints like `/api/admin/reports` or `/api/admin/inquiries`. However, we did not verify if the Spring Boot backend (`howmuch_backend`) actually implements these endpoints.
  - *Recommendation*: Recommend performing a backend-to-frontend schema/contract check to ensure suggested replacements match actual backend routes.

---

## Unverified Items

- **Backend Route Feasibility** — Insufficient context: We did not audit the Java Spring Boot codebase to check if mock-replacement REST controllers exist.

---

# PART 2: Adversarial Review Report

## Challenge Summary

**Overall Risk Assessment**: **MEDIUM**

While the mockup report compiles all obvious frontend mock data, the project faces operational and security risks due to uncommitted developer modifications, hardcoded ngrok tunnel URLs, and broken test assertions.

---

## Challenges

### [High] Challenge 1: Ngrok Backend Host Dependency
- **Assumption challenged**: The recommendation assumes that externalizing base URLs into environment variables is sufficient.
- **Attack scenario**: The ngrok free URL (`https://sulfurously-transhumant-dennise.ngrok-free.dev`) is hardcoded in `ai_chat_service.dart` and `user_profile_api_service.dart`. Free ngrok tunnels expire or rotate on restart.
- **Blast radius**: If the tunnel URL changes and is not updated in the deployed environment, the AI chat and user profile services will fail instantly with connection timeouts.
- **Mitigation**: Implement a central configurations provider/service that dynamically resolves the API gateway URL or reads it from local secure storage.

### [Medium] Challenge 2: Visit Verification Distance Bypass
- **Assumption challenged**: That checking distance dynamically via system GPS location prevents abuse of the visit verification feature.
- **Attack scenario**: GPS coordinates can be mocked or spoofed on mobile platforms (using developer options or location-mocking tools).
- **Blast radius**: Malicious users can fake visit verifications for "착한분식" and accumulate faked savings without physically visiting the store.
- **Mitigation**: Require cryptographic verification (e.g., photo metadata verification or server-side OCR on the receipt to extract date, time, and store business registration number).

---

## Stress Test Results

- **Run Widget Tests** &rarr; Expecting all tests to pass to verify regression integrity &rarr; All 17 widget tests failed due to Splash screen timeout and routing changes &rarr; **FAIL**

---

## Unchallenged Areas

- **Backend database security** — Out of scope for this frontend mockup audit.
