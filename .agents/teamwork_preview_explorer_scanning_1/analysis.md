# Analysis Report: Hardcoded Mockup Data Scan

This report documents the findings of a scan for hardcoded mockup/dummy data in the Dart files under the `admin`, `auth`, `community`, `errors`, and `home` features of the `howmuch` project.

---

## 1. Feature: admin

### `lib/features/admin/presentation/state/admin_state.dart`
* **Line Numbers**: 113-144
  * **Mockup Values**:
    * Hardcoded list of `AdminReportReview` in `adminReportsProvider` with mock stores "골목밥상" (price: 6,000원) and "동네카페" (price: 2,000원).
  * **Recommendation**:
    * Replace `StateProvider<List<AdminReportReview>>` with a Riverpod `FutureProvider` or `AsyncNotifierProvider` linked to an `AdminApiService` that fetches reports from a backend endpoint (e.g., `/api/admin/reports`).
* **Line Numbers**: 147-188
  * **Mockup Values**:
    * Hardcoded list of `AdminInquiry` in `adminInquiriesProvider` containing 4 mock inquiries ("제보한 매장이 7일째 검토 중이에요", "지도에서 마커가 사라져요", etc.).
  * **Recommendation**:
    * Replace with a dynamic provider linked to an inquiry API endpoint (e.g., `/api/admin/inquiries`).

### `lib/features/admin/presentation/screens/admin_inquiry_review_screen.dart`
* **Line Numbers**: 349
  * **Mockup Values**:
    * `'v2.4'` version string in header.
  * **Recommendation**:
    * Load from package info or environment variables.
* **Line Numbers**: 361
  * **Mockup Values**:
    * `'관리자 김'` admin name in header.
  * **Recommendation**:
    * Retrieve dynamically from the authenticated admin user's profile state.
* **Line Numbers**: 416
  * **Mockup Values**:
    * `'이번 주 신규 17건 · 평균 응답 4.2시간'` statistic text.
  * **Recommendation**:
    * Retrieve these aggregates from a backend statistics/dashboard endpoint.
* **Line Numbers**: 478-492 & 599-628
  * **Mockup Values**:
    * `figmaBase` and `initialVisible` count maps used to perform calculations to fake total counts for inquiries (waiting: 8, inProgress: 3, completed: 142).
  * **Recommendation**:
    * Count items directly from the inquiries state list, or get precise status counts from a backend summary response.

### `lib/features/admin/presentation/screens/admin_report_review_screen.dart`
* **Line Numbers**: 159-176
  * **Mockup Values**:
    * `figmaBase` and `initialVisible` count maps used to fake total counts for reports (fresh: 8, reviewing: 3, approved: 42, rejected: 2).
  * **Recommendation**:
    * Calculate counts dynamically based on actual reports matching each status or fetch from a summary API.
* **Line Numbers**: 813-818
  * **Mockup Values**:
    * `gradients` mockup color grids for photo previews in `_PhotoPreview`.
  * **Recommendation**:
    * Update `AdminReportReview` model to include a list of image URLs, and load actual network images using `CachedNetworkImage` rather than empty containers.

---

## 2. Feature: auth

### `lib/features/auth/presentation/state/auth_state.dart`
* **Line Numbers**: 35-42
  * **Mockup Values**:
    * Initial `AuthState` values: `isLoggedIn: false`, `isAdmin: false`, `provider: '이메일'`, `email: 'minseo@example.com'`.
  * **Recommendation**:
    * Set default values to null/empty and fetch actual authentication status asynchronously from secure storage upon application startup.

### `lib/features/auth/presentation/screens/login_screen.dart`
* **Line Numbers**: 181-193
  * **Mockup Values**:
    * Mock login logic inside `_loginWith` for Naver and Apple providers, manually setting auth state with `'user@example.com'` and displaying a mock success snackbar.
  * **Recommendation**:
    * Integrate Naver Login and Apple Sign-In SDKs, connecting token validation to `/api/auth/naver` and `/api/auth/apple` backend endpoints respectively.

### `lib/features/auth/presentation/screens/permission_setup_screen.dart`
* **Line Numbers**: 137-167
  * **Mockup Values**:
    * Statically declared cards with mockup status states (`allowed: true` or `allowed: false`).
  * **Recommendation**:
    * Query the actual system permission states using the `permission_handler` package, and update the cards to dynamically reflect the system permissions.

### `lib/features/auth/presentation/screens/profile_setup_screen.dart`
* **Line Numbers**: 43
  * **Mockup Values**:
    * Hardcoded API key `_kakaoRestApiKey = 'a262460cc196a9dd283003c7d54743b3'`.
  * **Recommendation**:
    * Move the API key to environment variables (using `--dart-define`) to secure it.
* **Line Numbers**: 51-54
  * **Mockup Values**:
    * Hardcoded list `_allCategories` for profile setup.
  * **Recommendation**:
    * Retrieve this list dynamically from a backend metadata endpoint.

---

## 3. Feature: community

### `lib/features/community/presentation/screens/community_feed_screen.dart`
* **Line Numbers**: 671-707
  * **Mockup Values**:
    * Hardcoded list `_feedItems` of 3 `_FeedItem` mock objects.
  * **Recommendation**:
    * Retrieve feed items dynamically from a `communityFeedProvider` populated by a backend community feed API.

### `lib/features/community/presentation/screens/community_post_detail_screen.dart`
* **Line Numbers**: 39-54
  * **Mockup Values**:
    * Hardcoded list of `_comments` (2 mockup comments).
  * **Recommendation**:
    * Retrieve comments dynamically via a comments API linked to the post ID.
* **Line Numbers**: 364-487
  * **Mockup Values**:
    * Statically declared `_PostCard` details representing a specific mockup post ("동네카페 아메리카노 2,500원으로 가격 인상됐어요", "by 강남직장인", "2026.05.14 · 역삼동", etc.).
  * **Recommendation**:
    * Accept the post ID as a constructor parameter, watch a details provider (e.g., `communityPostProvider(postId)`), and populate fields dynamically.

### `lib/features/community/presentation/screens/my_reports_screen.dart`
* **Line Numbers**: 91
  * **Mockup Values**:
    * `date: '2026.05.12'` hardcoded mockup date.
  * **Recommendation**:
    * Pull the real creation date from the report model.
* **Line Numbers**: 98
  * **Mockup Values**:
    * `notice: '메뉴판 사진이 흐려 가격 확인이 어려워요'` hardcoded caution notice.
  * **Recommendation**:
    * Fetch this reason/feedback directly from the report database details.
* **Line Numbers**: 314-320
  * **Mockup Values**:
    * Hardcoded tab counts `_items` (all: 3, pending: 1, approved: 1, needsEdit: 1, rejected: 0).
  * **Recommendation**:
    * Group and count reports dynamically by their status from the provider.
* **Line Numbers**: 499-511
  * **Mockup Values**:
    * Hardcoded total counts in summary card (`3건 승인 1건`).
  * **Recommendation**:
    * Compute count values dynamically from the loaded reports list.

### `lib/features/community/presentation/screens/my_reports/my_reports_v2_screen.dart`
* **Line Numbers**: 267-273
  * **Mockup Values**:
    * Hardcoded tab counts `_items` (all: 3, pending: 1, approved: 1, needsEdit: 1, rejected: 0).
  * **Recommendation**:
    * Compute count values dynamically from the Riverpod report list.

### `lib/features/community/presentation/screens/my_reports/tabs/my_reports_pending_tab.dart`
* **Line Numbers**: 23
  * **Mockup Values**:
    * `'보통 1~3일 안에 검토가 완료돼요.'` banner text.
  * **Recommendation**:
    * Display dynamically or keep as general placeholder.
* **Line Numbers**: 57
  * **Mockup Values**:
    * Unconditional rendering of `EmptyStateBox()` displaying "검토 중인 제보가 없어요" even when reports are listed.
  * **Recommendation**:
    * Make the rendering conditional: `if (visibleReports.isEmpty) const EmptyStateBox()`.

### `lib/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart`
* **Line Numbers**: 698 & 749
  * **Mockup Values**:
    * Hardcoded warning note `notice: '메뉴판 사진이 흐려 가격 확인이 어려워요'`.
  * **Recommendation**:
    * Bind to a nullable database field `rejectionReason` or `feedback` from the report model.
* **Line Numbers**: 708-756
  * **Mockup Values**:
    * `reportsData` fallback list of 3 mock reports.
  * **Recommendation**:
    * Ensure list is populated strictly from the backend through `myReportDataProvider`.

### `lib/features/community/presentation/screens/report_complete_screen.dart`
* **Line Numbers**: 293
  * **Mockup Values**:
    * `'현재 위치 근처'` string in the location field.
  * **Recommendation**:
    * Pull the real address or GPS location from the submitted report.

### `lib/features/community/presentation/screens/report_create_screen.dart`
* **Line Numbers**: 25-37
  * **Mockup Values**:
    * Hardcoded options: `_storeOptions`, `_addressOptions`, and `_categoryOptions`.
  * **Recommendation**:
    * Remove unused `_storeOptions` and `_addressOptions`. Retrieve categories dynamically from a backend endpoint.

### `lib/features/community/presentation/screens/report_detail_screen.dart`
* **Line Numbers**: Entire screen (182-227, 343-390, 426-491, 560-604, 743-786, etc.)
  * **Mockup Values**:
    * Statically declared mockup data ("착한김밥", "음식점 · 분식", "서울시 강남구 역삼동", "김밥 2,500원", mockup progress steps, etc.).
  * **Recommendation**:
    * Pass the report ID to the screen, watch a report details provider, and populate fields dynamically. If obsolete, deprecate in favor of `ReportDetailV2Screen`.

### `lib/features/community/presentation/screens/report_detail_v2_screen.dart`
* **Line Numbers**: Entire screen (206-234, 355-402, 500-505, etc.)
  * **Mockup Values**:
    * Ignored query parameter `id`, statically displaying mockup data ("골목밥상", "음식점 · 한식", "서울시 마포구 합정동", "제육덮밥 6,000원", etc.).
  * **Recommendation**:
    * Read the `id` from query parameters, query `myReportDataProvider` to fetch the specific report, and populate widgets dynamically.

---

## 4. Feature: errors

### `lib/features/errors/presentation/screens/favorite_cancel_confirm_screen.dart`
* **Line Numbers**: 42
  * **Mockup Values**:
    * Hardcoded store name `'착한분식'`.
  * **Recommendation**:
    * Pass the store name as a constructor parameter.

### `lib/features/errors/presentation/screens/store_info_report_screen.dart`
* **Line Numbers**: 15 & 17
  * **Mockup Values**:
    * Pre-filled text input controllers with mockup price `'6,000'` and mockup description `'어제 방문했을 때 메뉴판에 6,000원으로 표기되어 있었어요.'`.
  * **Recommendation**:
    * Empty out inputs or dynamically pre-populate based on selected store details.
* **Line Numbers**: 153 & 158
  * **Mockup Values**:
    * Hardcoded store card details: `'착한분식'`, `'서울 강남구 역삼동 123-4 · 김치찌개 5,500원'`.
  * **Recommendation**:
    * Pass the selected store model/parameters to this screen and populate values dynamically.

---

## 5. Feature: home

### `lib/features/home/presentation/screens/home_map_screen.dart`
* **Line Numbers**: 1539
  * **Mockup Values**:
    * Hardcoded weather temperature value `'18°'`.
  * **Recommendation**:
    * Fetch real weather data from an external weather API or a backend weather cache endpoint.
* **Line Numbers**: 1611
  * **Mockup Values**:
    * Hardcoded spotlight collection title `'따뜻한 국물 메뉴 3곳'`.
  * **Recommendation**:
    * Query the current active AI Spotlight recommendations from the backend.
* **Line Numbers**: 1723
  * **Mockup Values**:
    * Hardcoded rating value `'4.6'` for all stores on the summary card.
  * **Recommendation**:
    * Retrieve and show the actual average rating/reviews score of each store from the `Store` model.
* **Line Numbers**: 1802
  * **Mockup Values**:
    * Hardcoded savings label `'평균 대비 2,000원 절약'`.
  * **Recommendation**:
    * Calculate the price difference dynamically compared to the regional industry average.
* **Line Numbers**: 1935
  * **Mockup Values**:
    * Hardcoded price marker text `'●  착한분식 5,500원'`.
  * **Recommendation**:
    * Remove this unused static component or bind it to dynamic store coordinates/prices.
* **Line Numbers**: 1854
  * **Mockup Values**:
    * `_HomeMapPainter` fallback drawing roads/park/water when map SDK doesn't render.
  * **Recommendation**:
    * Keep map rendering strictly within WebView/Kakao Map API to ensure a real interactive map, showing error indicators rather than drawings when loading fails.
