# Handoff Report: Scan for Hardcoded Mockup Data in Features

## 1. Observation
Across the 5 assigned feature directories ('admin', 'auth', 'community', 'errors', 'home') under `/Users/min/Documents/howmuch/lib/features/`, Dart source code files were inspected. The following instances of hardcoded mockup data were directly observed:

### Admin Feature
- **File**: `lib/features/admin/presentation/state/admin_state.dart`
  - **Lines 113-144**: `final adminReportsProvider = StateProvider<List<AdminReportReview>>((ref) => const [...]` contains two hardcoded mock `AdminReportReview` objects.
  - **Lines 147-188**: `final adminInquiriesProvider = StateProvider<List<AdminInquiry>>((ref) => const [...]` contains four hardcoded mock `AdminInquiry` objects.
- **File**: `lib/features/admin/presentation/screens/admin_inquiry_review_screen.dart`
  - **Line 349**: `const Center(child: Text('v2.4', style: _versionText))`
  - **Line 361**: `const Text('관리자 김', style: _adminUserText)`
  - **Line 416**: `Text('이번 주 신규 17건 · 평균 응답 4.2시간', style: _subtitleText)`
  - **Lines 478-492 & 599-628**: `_displayCount` and `_countFor` use `figmaBase` and `initialVisible` to adjust stats counts.
- **File**: `lib/features/admin/presentation/screens/admin_report_review_screen.dart`
  - **Lines 159-176**: `_displayCount` adjusts status count using `figmaBase`.
  - **Lines 813-818**: Mock gradients in `_PhotoPreview` color grids.

### Auth Feature
- **File**: `lib/features/auth/presentation/state/auth_state.dart`
  - **Lines 35-42**: `authStateProvider` initialized with email `'minseo@example.com'` and provider `'이메일'`.
- **File**: `lib/features/auth/presentation/screens/login_screen.dart`
  - **Lines 181-193**: `_loginWith` updates auth state with a mock email `'user@example.com'` for non-Kakao social login attempts.
- **File**: `lib/features/auth/presentation/screens/permission_setup_screen.dart`
  - **Lines 137-167**: Statically declared cards with mockup status states (`allowed: true`/`allowed: false`).
- **File**: `lib/features/auth/presentation/screens/profile_setup_screen.dart`
  - **Line 43**: `_kakaoRestApiKey = 'a262460cc196a9dd283003c7d54743b3'` (Hardcoded API key).
  - **Lines 51-54**: Hardcoded list of categories `_allCategories`.

### Community Feature
- **File**: `lib/features/community/presentation/screens/community_feed_screen.dart`
  - **Lines 671-707**: Hardcoded mock items list `_feedItems`.
- **File**: `lib/features/community/presentation/screens/community_post_detail_screen.dart`
  - **Lines 39-54**: Hardcoded comments list `_comments`.
  - **Lines 364-487**: Statically declared card widget `_PostCard` details.
- **File**: `lib/features/community/presentation/screens/my_reports_screen.dart`
  - **Line 91**: Hardcoded report date `'2026.05.12'`.
  - **Line 98**: Hardcoded report caution notice `'메뉴판 사진이 흐려 가격 확인이 어려워요'`.
  - **Lines 314-320**: Hardcoded tab counts.
  - **Lines 499-511**: Hardcoded total counts in summary card.
- **File**: `lib/features/community/presentation/screens/my_reports/my_reports_v2_screen.dart`
  - **Lines 267-273**: Hardcoded tab counts.
- **File**: `lib/features/community/presentation/screens/my_reports/tabs/my_reports_pending_tab.dart`
  - **Line 23**: Hardcoded banner text `'보통 1~3일 안에 검토가 완료돼요.'`.
  - **Line 57**: Unconditionally rendered `EmptyStateBox()`.
- **File**: `lib/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart`
  - **Lines 698 & 749**: Hardcoded warning note.
  - **Lines 708-756**: Mock `reportsData` fallback list.
- **File**: `lib/features/community/presentation/screens/report_complete_screen.dart`
  - **Line 293**: Location description `'현재 위치 근처'` is hardcoded.
- **File**: `lib/features/community/presentation/screens/report_create_screen.dart`
  - **Lines 25-37**: Hardcoded `_storeOptions`, `_addressOptions`, `_categoryOptions`.
- **File**: `lib/features/community/presentation/screens/report_detail_screen.dart`
  - **Entire Screen**: Statically declared mockup cards (`_ReportInfoCard`, `_PriceLine`, `_ProgressSteps`, `_ReasonCard`, `_PhotoSection`, `_DescriptionSection`).
- **File**: `lib/features/community/presentation/screens/report_detail_v2_screen.dart`
  - **Entire Screen**: Statically declared mockup data, completely ignoring the passed query parameter `id`.

### Errors Feature
- **File**: `lib/features/errors/presentation/screens/favorite_cancel_confirm_screen.dart`
  - **Line 42**: Hardcoded store name `'착한분식'`.
- **File**: `lib/features/errors/presentation/screens/store_info_report_screen.dart`
  - **Lines 15 & 17**: Hardcoded initial text controllers values.
  - **Lines 153 & 158**: Hardcoded store card details.

### Home Feature
- **File**: `lib/features/home/presentation/screens/home_map_screen.dart`
  - **Line 1539**: Hardcoded temperature `'18°'`.
  - **Line 1611**: Hardcoded spotlight collection title `'따뜻한 국물 메뉴 3곳'`.
  - **Line 1723**: Hardcoded rating value `'4.6'`.
  - **Line 1802**: Hardcoded savings label `'평균 대비 2,000원 절약'`.
  - **Line 1935**: Hardcoded price marker text `'●  착한분식 5,500원'`.
  - **Line 1854**: `_HomeMapPainter` fallback drawing roads/park/water.

---

## 2. Logic Chain
1. **Mock State Identification**: Standard Riverpod providers, such as `adminReportsProvider`, `adminInquiriesProvider`, `authStateProvider`, and `myReportDataProvider`, default to hardcoded list models or configuration profiles.
2. **Mock UI Binding**: Several screens (`admin_inquiry_review_screen.dart`, `admin_report_review_screen.dart`, `community_feed_screen.dart`, `community_post_detail_screen.dart`, `my_reports_screen.dart`, `report_complete_screen.dart`, `report_detail_screen.dart`, `report_detail_v2_screen.dart`, `store_info_report_screen.dart`, `home_map_screen.dart`) either display these static provider lists or bind labels to static hardcoded text directly (e.g. `v2.4`, `관리자 김`, `착한분식`, `4.6`).
3. **Logic Faking**: Aggregate counts and progress indicators (such as tab counts or status aggregates) are calculated using static constants (`figmaBase` or `figmaCounts`) to make the UI match Figma designs rather than reflecting the actual length of loaded data arrays.
4. **Conclusion Formulation**: Therefore, a transition from prototype to production requires refactoring these providers to use asynchronous API clients and replacing hardcoded UI widgets with dynamically bound fields.

---

## 3. Caveats
- This was a read-only investigation. No functional changes, refactoring, or source code modifications were performed.
- Sub-features or utility directories other than `admin`, `auth`, `community`, `errors`, and `home` under `/Users/min/Documents/howmuch/lib/features/` were not scanned.

---

## 4. Conclusion
The codebase is heavily mockup-reliant for UI presentation, containing multiple hardcoded lists of reviews, inquiries, comments, store descriptions, aggregates, and faked count logic. To make the application ready for dynamic production use, these mockup elements must be replaced with dynamic data loading via Riverpod providers integrated with backend API routes.

---

## 5. Verification Method
- **Files to Inspect**:
  - `/Users/min/Documents/howmuch/.agents/teamwork_preview_explorer_scanning_1/analysis.md` (Detailed analysis report).
  - The specific files and line numbers cited under the **Observation** section.
- **Command to run**:
  - Run the Flutter build/analyze command to ensure no new syntax errors exist:
    `flutter analyze` (No source code changes were made, so analyze will pass).
