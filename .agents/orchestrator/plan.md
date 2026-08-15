# Project Plan: Mockup Data Scan and Report

We will perform a codebase scan on `lib/features/**/*.dart` to identify hardcoded mockup data.
All actions will be read-only and no source code will be modified.

## Phase 1: Codebase Scanning (R1)
1. **Goal**: Locate all instances of hardcoded mockup data in `lib/features`.
2. **Strategy**:
   - Focus on UI code, especially screen and widget files.
   - Look for hardcoded string literals, mock lists, or dummy data that should/could be loaded dynamically.
   - Highlight instances where data could be retrieved via Riverpod (`ref.watch`, `ref.read`), GoRouter (`state.extra`), or constructor arguments but is hardcoded instead.
   - Pay special attention to the example `visit_verification_screen.dart` containing "착한분식".
3. **Execution**: Dispatch a read-only Explorer subagent to perform grep searches, view files, and list resources to compile a list of all mockup data candidates.

## Phase 2: Report Compilation (R2)
1. **Goal**: Write a well-structured `mockup_report.md` in the project workspace root.
2. **Details**:
   - Relative file paths and line numbers.
   - Hardcoded mockup content/values.
   - Actionable suggestions for dynamic data integration (e.g. specific providers or widgets).
3. **Execution**: Dispatch a Worker subagent to construct the report markdown based on Explorer's findings.

## Phase 3: Review and Verification (R3)
1. **Goal**: Verify that the report is accurate, formatted correctly, and contains the required content (especially the "착한분식" example), and that the codebase remains completely unmodified.
2. **Execution**: Dispatch a Reviewer subagent to audit the report and verify code integrity.

## Phase 4: Sign-off
1. **Goal**: Present findings and report success to the Sentinel.
