# Hardcoded Mockup Data Scanning - Unified Analysis Report

This report compiles all mockup and dummy data findings across the codebase of the `howmuch` application, scanned by three Explorer subagents. It categorizes the findings by feature and provides concrete recommendations for replacing hardcoded values with dynamic data sources.

---

## 1. Feature: admin

| File Path | Line Number(s) | Hardcoded Mockup Content/Values | Dynamic Replacement Recommendation / Proposed Data Source |
|---|---|---|---|
| `lib/features/admin/presentation/state/admin_state.dart` | 113–144 | List of `AdminReportReview` with mock stores "골목밥상" (price: 6,000원) and "동네카페" (price: 2,000원) in `adminReportsProvider`. | Replace `StateProvider<List<AdminReportReview>>` with a Riverpod `FutureProvider` or `AsyncNotifierProvider` linked to `AdminApiService` to fetch reports from `/api/admin/reports`. |
| `lib/features/admin/presentation/state/admin_state.dart` | 147–188 | List of `AdminInquiry` with 4 mock inquiries ("제보한 매장이 7일째 검토 중이에요", "지도에서 마커가 사라져요", etc.) in `adminInquiriesProvider`. | Replace with a dynamic provider linked to `/api/admin/inquiries`. |
| `lib/features/admin/presentation/screens/admin_inquiry_review_screen.dart` | 349 | Version string `'v2.4'` in header. | Load dynamically from package info or environment configurations. |
| `lib/features/admin/presentation/screens/admin_inquiry_review_screen.dart` | 361 | Admin name `'관리자 김'` in header. | Retrieve dynamically from the authenticated admin user's profile state. |
| `lib/features/admin/presentation/screens/admin_inquiry_review_screen.dart` | 416 | Statistics text `'이번 주 신규 17건 · 평균 응답 4.2시간'`. | Retrieve these aggregates from a backend statistics/dashboard endpoint. |
| `lib/features/admin/presentation/screens/admin_inquiry_review_screen.dart` | 478–492, 599–628 | `figmaBase` and `initialVisible` count maps used to fake total counts for inquiries (waiting: 8, inProgress: 3, completed: 142). | Count items directly from the inquiries state list, or get precise status counts from a backend summary response. |
| `lib/features/admin/presentation/screens/admin_report_review_screen.dart` | 159–176 | `figmaBase` and `initialVisible` count maps used to fake total counts for reports (fresh: 8, reviewing: 3, approved: 42, rejected: 2). | Calculate counts dynamically based on actual reports matching each status or fetch from a summary API. |
| `lib/features/admin/presentation/screens/admin_report_review_screen.dart` | 813–818 | Mockup color grids `gradients` in `_PhotoPreview`. | Update the `AdminReportReview` model to include image URLs, and load actual network images using `CachedNetworkImage`. |

---

## 2. Feature: auth

| File Path | Line Number(s) | Hardcoded Mockup Content/Values | Dynamic Replacement Recommendation / Proposed Data Source |
|---|---|---|---|
| `lib/features/auth/presentation/state/auth_state.dart` | 35–42 | Initial `AuthState` values: `isLoggedIn: false`, `isAdmin: false`, `provider: '이메일'`, `email: 'minseo@example.com'`. | Set default values to null/empty and fetch actual authentication status asynchronously from secure storage upon application startup. |
| `lib/features/auth/presentation/screens/login_screen.dart` | 181–193 | Mock login logic inside `_loginWith` for Naver and Apple providers, manually setting auth state with `'user@example.com'` and displaying a mock success snackbar. | Integrate Naver Login and Apple Sign-In SDKs, connecting token validation to `/api/auth/naver` and `/api/auth/apple` backend endpoints respectively. |
| `lib/features/auth/presentation/screens/permission_setup_screen.dart` | 137–167 | Statically declared cards with mockup status states (`allowed: true` or `allowed: false`). | Query the actual system permission states using the `permission_handler` package, and update the cards to dynamically reflect the system permissions. |
| `lib/features/auth/presentation/screens/profile_setup_screen.dart` | 43 | Hardcoded API key `_kakaoRestApiKey = 'a262460cc196a9dd283003c7d54743b3'`. | Move the API key to environment variables (using `--dart-define`) to secure it. |
| `lib/features/auth/presentation/screens/profile_setup_screen.dart` | 51–54 | Hardcoded list `_allCategories` for profile setup. | Retrieve this list dynamically from a backend metadata endpoint. |

---

## 3. Feature: community

| File Path | Line Number(s) | Hardcoded Mockup Content/Values | Dynamic Replacement Recommendation / Proposed Data Source |
|---|---|---|---|
| `lib/features/community/presentation/screens/community_feed_screen.dart` | 671–707 | Hardcoded list `_feedItems` of 3 `_FeedItem` mock objects. | Retrieve feed items dynamically from a `communityFeedProvider` populated by a backend community feed API. |
| `lib/features/community/presentation/screens/community_post_detail_screen.dart` | 39–54 | Hardcoded list of `_comments` (2 mockup comments). | Retrieve comments dynamically via a comments API linked to the post ID. |
| `lib/features/community/presentation/screens/community_post_detail_screen.dart` | 364–487 | Statically declared `_PostCard` details representing a specific mockup post ("동네카페 아메리카노 2,500원으로 가격 인상됐어요", "by 강남직장인", "2026.05.14 · 역삼동", etc.). | Accept the post ID as a constructor parameter, watch a details provider (e.g., `communityPostProvider(postId)`), and populate fields dynamically. |
| `lib/features/community/presentation/screens/my_reports_screen.dart` | 91 | `date: '2026.05.12'` hardcoded mockup date. | Pull the real creation date from the report model. |
| `lib/features/community/presentation/screens/my_reports_screen.dart` | 98 | `notice: '메뉴판 사진이 흐려 가격 확인이 어려워요'` hardcoded caution notice. | Fetch this reason/feedback directly from the report database details. |
| `lib/features/community/presentation/screens/my_reports_screen.dart` | 314–320 | Hardcoded tab counts `_items` (all: 3, pending: 1, approved: 1, needsEdit: 1, rejected: 0). | Group and count reports dynamically by their status from the provider. |
| `lib/features/community/presentation/screens/my_reports_screen.dart` | 499–511 | Hardcoded total counts in summary card (`3건 승인 1건`). | Compute count values dynamically from the loaded reports list. |
| `lib/features/community/presentation/screens/my_reports/my_reports_v2_screen.dart` | 267–273 | Hardcoded tab counts `_items` (all: 3, pending: 1, approved: 1, needsEdit: 1, rejected: 0). | Compute count values dynamically from the Riverpod report list. |
| `lib/features/community/presentation/screens/my_reports/tabs/my_reports_pending_tab.dart` | 23 | `'보통 1~3일 안에 검토가 완료돼요.'` banner text. | Display dynamically or keep as general placeholder. |
| `lib/features/community/presentation/screens/my_reports/tabs/my_reports_pending_tab.dart` | 57 | Unconditional rendering of `EmptyStateBox()` displaying "검토 중인 제보가 없어요" even when reports are listed. | Make the rendering conditional: `if (visibleReports.isEmpty) const EmptyStateBox()`. |
| `lib/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart` | 698 & 749 | Hardcoded warning note `notice: '메뉴판 사진이 흐려 가격 확인이 어려워요'`. | Bind to a nullable database field `rejectionReason` or `feedback` from the report model. |
| `lib/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart` | 708–756 | `reportsData` fallback list of 3 mock reports. | Ensure list is populated strictly from the backend through `myReportDataProvider`. |
| `lib/features/community/presentation/screens/report_complete_screen.dart` | 293 | `'현재 위치 근처'` string in the location field. | Pull the real address or GPS location from the submitted report. |
| `lib/features/community/presentation/screens/report_create_screen.dart` | 25–37 | Hardcoded options: `_storeOptions`, `_addressOptions`, and `_categoryOptions`. | Remove unused `_storeOptions` and `_addressOptions`. Retrieve categories dynamically from a backend endpoint. |
| `lib/features/community/presentation/screens/report_detail_screen.dart` | 182–227, 343–390, 426–491, 560–604, 743–786 | Statically declared mockup data ("착한김밥", "음식점 · 분식", "서울시 강남구 역삼동", "김밥 2,500원", mockup progress steps, etc.). | Pass the report ID to the screen, watch a report details provider, and populate fields dynamically. If obsolete, deprecate in favor of `ReportDetailV2Screen`. |
| `lib/features/community/presentation/screens/report_detail_v2_screen.dart` | 206–234, 355–402, 500–505 | Ignored query parameter `id`, statically displaying mockup data ("골목밥상", "음식점 · 한식", "서울시 마포구 합정동", "제육덮밥 6,000원", etc.). | Read the `id` from query parameters, query `myReportDataProvider` to fetch the specific report, and populate widgets dynamically. |

---

## 4. Feature: errors

| File Path | Line Number(s) | Hardcoded Mockup Content/Values | Dynamic Replacement Recommendation / Proposed Data Source |
|---|---|---|---|
| `lib/features/errors/presentation/screens/favorite_cancel_confirm_screen.dart` | 42 | Hardcoded store name `'착한분식'`. | Pass the store name as a constructor parameter. |
| `lib/features/errors/presentation/screens/store_info_report_screen.dart` | 15 & 17 | Pre-filled text input controllers with mockup price `'6,000'` and mockup description `'어제 방문했을 때 메뉴판에 6,000원으로 표기되어 있었어요.'`. | Empty out inputs or dynamically pre-populate based on selected store details. |
| `lib/features/errors/presentation/screens/store_info_report_screen.dart` | 153 & 158 | Hardcoded store card details: `'착한분식'`, `'서울 강남구 역삼동 123-4 · 김치찌개 5,500원'`. | Pass the selected store model/parameters to this screen and populate values dynamically. |

---

## 5. Feature: home

| File Path | Line Number(s) | Hardcoded Mockup Content/Values | Dynamic Replacement Recommendation / Proposed Data Source |
|---|---|---|---|
| `lib/features/home/presentation/screens/home_map_screen.dart` | 1539 | Hardcoded weather temperature value `'18°'`. | Fetch real weather data from an external weather API or a backend weather cache endpoint. |
| `lib/features/home/presentation/screens/home_map_screen.dart` | 1611 | Hardcoded spotlight collection title `'따뜻한 국물 메뉴 3곳'`. | Query the current active AI Spotlight recommendations from the backend. |
| `lib/features/home/presentation/screens/home_map_screen.dart` | 1723 | Hardcoded rating value `'4.6'` for all stores on the summary card. | Retrieve and show the actual average rating/reviews score of each store from the `Store` model. |
| `lib/features/home/presentation/screens/home_map_screen.dart` | 1802 | Hardcoded savings label `'평균 대비 2,000원 절약'`. | Calculate the price difference dynamically compared to the regional industry average. |
| `lib/features/home/presentation/screens/home_map_screen.dart` | 1935 | Hardcoded price marker text `'●  착한분식 5,500원'`. | Remove this unused static component or bind it to dynamic store coordinates/prices. |
| `lib/features/home/presentation/screens/home_map_screen.dart` | 1854 | `_HomeMapPainter` fallback drawing roads/park/water when map SDK doesn't render. | Keep map rendering strictly within WebView/Kakao Map API to ensure a real interactive map, showing error indicators rather than drawings when loading fails. |

---

## 6. Feature: recommendation

| File Path | Line Number(s) | Hardcoded Mockup Content/Values | Dynamic Replacement Recommendation / Proposed Data Source |
|---|---|---|---|
| `lib/features/recommendation/presentation/screens/optimal_route_screen.dart` | 95–153, 168–178, 189–260 | Mock Map Markers: `1 착한분식`, `2 동네카페` layout offsets.<br>Route Steps: Step 1: `storeName: '착한분식'`, `details: '김치찌개 5,500원 · 320m'`; Connection: `'도보 6분'`; Step 2: `storeName: '동네카페'`, `details: '아메리카노 2,000원 · 500m'`.<br>Summary Card: Total cost `'7,500원'`, Total savings `'약 4,300원'`, Total distance `'총 820m'`, Total estimated time `'예상 소요 12분'`. | Define `OptimalRoute`, `RouteStep`, and `RoutePath` models. Introduce `optimalRouteProvider` to fetch recommended path details dynamically based on coordinates or chosen stores. Make `OptimalRouteScreen` watch this provider. |
| `lib/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart` | 27–35, 469–478 | Quick Prompts: `'만원 이하 점심 추천'`, `'비 오는 날 따뜻한 국물'`, `'혼밥하기 좋은 분식'`, `'이 근처 오후 코스 짜줘'`. Greeting Message: `'고객님'` name placeholder. | Load quick prompts from a configuration service or API response. Interpolate current authenticated user's nickname from `userProfileProvider` in the greeting bubble. |
| `lib/features/recommendation/presentation/state/ai_chat_service.dart` | 9, 12 | Backend Host: `_backendHost` IP. Endpoint URL: `https://sulfurously-transhumant-dennise.ngrok-free.dev/api/ai/chat`. | Fetch base URL/API endpoint from environment variables (`String.fromEnvironment`) or an app-level configuration provider. |
| `lib/features/recommendation/presentation/screens/todays_pick_screen.dart` | 42–91, 187, 202, 216, 238 | Mock Items: "착한칼국수", "골목국밥", "정다운분식", "초가집삼계탕" with static prices, distances, and tags.<br>Weather Card: Date `'2026.05.16 (토)'`, Weather comment `'비가 오는 날이네요 ☔️'`, Temperature `'18°'`, Recommendation `'🍜 따뜻한 국물 메뉴를 추천해요'`. | Integrate a Weather Service Provider (`weatherProvider`) to fetch live weather, temperature, and date. Replace static items with `todaysPickProvider` fetching recommendations from the backend based on location, preferences, and weather. |

---

## 7. Feature: mypage

| File Path | Line Number(s) | Hardcoded Mockup Content/Values | Dynamic Replacement Recommendation / Proposed Data Source |
|---|---|---|---|
| `lib/features/mypage/presentation/state/mypage_state.dart` | 317–331, 351–375, 377–412, 415–473 | User Profile: `userProfileProvider` mock values (nickname: `'절약왕 민서'`, saved amount: `24500`, etc.). Price Alert Subscriptions: "착한분식", "동네카페", "착한미용실". Social Accounts: linked account records with dates `'2025.10.04'`, `'2026.02.18'`. Favorite Stores list. | Connect these providers to repositories that perform actual API requests (e.g. `UserProfileApiService`). Use dynamic credentials from `authStateProvider` to pull authenticated user profile records. |
| `lib/features/mypage/presentation/screens/mypage_screen.dart` | 167 | Admin Mode Toggle: Temporary local developer state override. | Implement dynamic admin privilege verification by checking user role/permissions against auth state properties or backend verification endpoint metadata. |
| `lib/features/mypage/presentation/screens/account_management_screen.dart` | 297–302 | Location Permission Text: Hardcoded value `'허용'`. | Check application location permission status dynamically using a permission state controller/provider. |
| `lib/features/mypage/presentation/screens/inquiry_screen.dart` | 46–50 | Text Controllers: Title `'착한분식 가격이 변경된 것 같아요'`, Body `'지난 주에 방문했을 때 김치찌개가 6,000원이었어요.\n가격 확인 부탁드립니다.'`. | Clear initial controller strings to leave fields empty by default. Add these strings as placeholders using `hintText` in `InputDecoration`. |
| `lib/features/mypage/presentation/screens/my_reviews_screen.dart` | 12–40, 155 | Reviews List: Dummy reviews ("착한분식", "동네카페", "착한미용실"). Average Rating: `'4.7'`. | Fetch reviews written by the active user from an API provider (e.g. `userReviewsProvider`). Calculate average ratings dynamically based on reviews list metrics. |
| `lib/features/mypage/presentation/screens/notification_settings_screen.dart` | 434 | Subscription Summary Subtitle: `'매장 3곳 · 메뉴 5개 관리'`. | Derive this count dynamically from active sub-elements inside `priceAlertSettingsProvider`. |
| `lib/features/mypage/presentation/screens/visit_history_screen.dart` | 13–50, 66, 116, 136 | Visit Items List: Mock visits array. Total Count: `'4'`, Monthly Visits: `'6'`, Monthly Savings: `'24,500원'`. | Setup a `visitHistoryProvider` to fetch history from the backend. Compute total visits, monthly visits, and monthly savings dynamically from the fetched visit list. |
| `lib/features/mypage/presentation/screens/withdrawal_screen.dart` | 320–324 | Warning Summary: user count values showing `'2건'`, `'12곳'`, `'24,500원 누적'`, `'7개'`, `'5개 메뉴'`. | Dynamically read these metrics from active providers (e.g. `userProfileProvider`, `favoriteStoresProvider`, etc.) to show exact, real-time user-specific warnings. |
| `lib/features/mypage/presentation/state/user_profile_api_service.dart` | 6–8 | Base URL: Hardcoded ngrok endpoint URL (`https://sulfurously-transhumant-dennise.ngrok-free.dev`). | Externalize URL endpoints into global app configs/environment variables. |

---

## 8. Feature: onboarding
- **Onboarding Illustrations**: Slide data descriptions and artwork placeholders (e.g. `'내 주변 착한가격업소를 한눈에'`, price labels in painters) are static content elements.
- **Recommendation**: These are typical static UI illustrations rather than mockup data that requires dynamic API integration. However, internationalization (i18n) can be added via ARB files if localized strings are needed.

---

## 9. Feature: store

| File Path | Line Number(s) | Hardcoded Mockup Content/Values | Dynamic Replacement Recommendation / Proposed Data Source |
|---|---|---|---|
| `lib/features/store/presentation/screens/visit_verification_screen.dart` | 76 | Hardcoded distance text `"매장 근처에 있을 때 인증할 수 있어요. 현재 거리: 320m"`. | Compute distance dynamically using a geolocator service compared with the store's lat/lng coordinates. |
| `lib/features/store/presentation/screens/visit_verification_screen.dart` | 123 | Hardcoded store name `"착한분식"`. | Accept a `Store` object or a `storeId` string in the widget constructor, and pull the store name (`store.storeName`). |
| `lib/features/store/presentation/screens/visit_verification_screen.dart` | 128 | Hardcoded menu and price info `"김치찌개 5,500원"`. | Dynamically display the menu item name and price from the store's main/selected menu (`"${store.mainMenu} ${formatPrice(store.mainMenuPrice)}"`). |
| `lib/features/store/presentation/screens/visit_verification_screen.dart` | 141 | Hardcoded distance badge `"320m"`. | Display the dynamically calculated distance badge. |
| `lib/features/store/presentation/screens/visit_verification_screen.dart` | 325 | Hardcoded expected savings amount `"약 2,000원 절약"`. | Compute expected savings by comparing the store's price with the neighborhood average price, retrieved via a price average API. |
| `lib/features/store/presentation/screens/directions_external_app_screen.dart` | 20–22 | Hardcoded transport travel times: `"6분"`, `"10분"`, `"4분"`. | Calculate travel times using the Google/Naver Directions API or launch external map apps with coordinates. |
| `lib/features/store/presentation/screens/directions_external_app_screen.dart` | 27 & 43 | Hardcoded search queries: `"착한분식 서울시 강남구 역삼동"`. | Construct map queries dynamically: `"${store.storeName} ${store.address}"`. |
| `lib/features/store/presentation/screens/directions_external_app_screen.dart` | 154 & 159 & 173 | Hardcoded store name `"착한분식"`, address `"서울시 강남구 역삼동"`, and distance `"320m"`. | Pass the current `Store` object to the screen, retrieve fields dynamically, and compute distance. |
| `lib/features/store/presentation/screens/price_change_report_screen.dart` | 23–24 | Hardcoded pre-populated controllers: `'아메리카노'`, `'2,500'`. | Accept `Store` and `Menu` parameters to pre-fill the form controllers dynamically. |
| `lib/features/store/presentation/screens/price_change_report_screen.dart` | 162 & 172 & 179 | Hardcoded store name `"동네카페"`, menu name `"아메리카노"`, and price `"2,000원"`. | Bind existing store details and menu details using widget state arguments. |
| `lib/features/store/presentation/screens/price_history_screen.dart` | 68 & 80 | Hardcoded store/menu title `"착한분식 · 김치찌개"`, current registered price `"5,500원"`. | Fetch price history logs from a repository/API using `storeId` and `menuId`. |
| `lib/features/store/presentation/screens/price_history_screen.dart` | 93–125 & 178–211 | Hardcoded chart labels (`"2025.06"`, `"5,500원 (현재)"`, `"5,000원 (이전)"`) and timeline lists. | Represent history as a list of DTOs and bind them to the bar chart heights and timeline builder dynamically. |
| `lib/features/store/presentation/screens/review_list_screen.dart` | 20–51 | Hardcoded mock reviews array `_reviews` containing names, ratings, contents, and replies. | Connect to a `reviewsProvider` or similar service to fetch reviews dynamically based on `storeId`. |
| `lib/features/store/presentation/screens/review_list_screen.dart` | 99 & 142 & 146 | Hardcoded store name `"착한분식"`, average rating `"4.8"`, and review count `" · 리뷰 128"`. | Calculate average rating and total counts from the fetched reviews database payload dynamically. |
| `lib/features/store/presentation/screens/review_write_screen.dart` | 22–23 | Hardcoded pre-populated controllers: `'김치찌개'`, `'5,500'`. | Bind inputs dynamically based on the current context passed via widget construction. |
| `lib/features/store/presentation/screens/review_write_screen.dart` | 175 & 180 | Hardcoded store name `"착한분식"`, address `"서울 강남구 역삼동"`. | Populate values dynamically from the store object. |
| `lib/features/store/presentation/screens/store_detail_screen.dart` | 173, 182, 189, 219, 227, 421, 422, 484, 500–515 | Hardcoded mock average rating `"4.6"`, review count `"리뷰 128"`, mock tags, expected savings `"2,000"`, business hours `"정보 없음"` with `isMock: true`, mock reviews for `김○○` and `이○○`. | Update the `Store` model to support fields like `rating`, `reviewCount`, `businessHours`, and `expectedSavings`. Fetch real reviews via provider. |
| `lib/features/store/presentation/screens/visit_verification_complete_screen.dart` | 66, 82, 113, 121 | Hardcoded savings `"2,000원"`, monthly savings `"26,500원"`, store name `"착한분식"`, menu and price info `"김치찌개 5,500원"`. | Pass completed verification transaction details (saved amount, store details, cumulative savings) as arguments when navigating to this screen. |

---

## 10. Feature: savings

| File Path | Line Number(s) | Hardcoded Mockup Content/Values | Dynamic Replacement Recommendation / Proposed Data Source |
|---|---|---|---|
| `lib/features/savings/presentation/screens/savings_detail_screen.dart` | 40–85 | Hardcoded array of `SavingsDetailItem` in `_allItems`. | Fetch savings records using a database/repository provider (e.g. `savingsHistoryProvider`). |
| `lib/features/savings/presentation/screens/savings_detail_screen.dart` | 198, 225, 235 | Hardcoded total monthly savings `"24,500"`, visit count `"📍 6회 방문"`, and average savings `"· 평균 4,083원 절약"`. | Calculate monthly totals, visit frequency, and average savings programmatically from the retrieved dataset. |
| `lib/features/savings/presentation/screens/savings_goal_setting_screen.dart` | 206–207, 216–217, 226–227 | Category progress values: "음식점" (`"14,500원"`, `" / 20,000원"`), "카페" (`"6,500원"`, `" / 8,000원"`), "생활서비스" (`"3,500원"`, `" / 5,000원"`). | Query category-specific limits and achievements from a settings or profile database. Bind to reactive states. |
| `lib/features/savings/presentation/screens/savings_report_dashboard_screen.dart` | 197–200, 208, 212–215, 223, 227–231, 202–204, 217–219, 233–235, 205, 220, 236 | Hardcoded weekly and monthly bar chart stats; visit, favorite, and report counts; recommendations subheadings. | Feed chart bars and dashboard metrics from a dashboard stats service that groups records based on the selected timeframe. |
| `lib/features/savings/presentation/state/savings_state.dart` | 9, 12 | Hardcoded initial goal `30000` and achievement rate `24500` in `ValueNotifier`. | Retrieve these states from local preferences/secure storage during initialization, fallback to defaults if empty. |

---

## 11. Feature: search

| File Path | Line Number(s) | Hardcoded Mockup Content/Values | Dynamic Replacement Recommendation / Proposed Data Source |
|---|---|---|---|
| `lib/features/search/presentation/screens/search_result_screen.dart` | 221–273 | Mock fallback results `_mockResults(String q)` for store search. | Integrate actual search API querying the backend database. |
| `lib/features/search/presentation/screens/search_result_screen.dart` | 1039–1044 | Hardcoded search suggestion tags (e.g. `'김치찌개'`, `'아메리카노'`) and chip widths. | Fetch recommendation terms from a trending-search API. Use standard Flutter `Wrap` flow layouts without fixed widths. |

---

## 12. Feature: system

| File Path | Line Number(s) | Hardcoded Mockup Content/Values | Dynamic Replacement Recommendation / Proposed Data Source |
|---|---|---|---|
| `lib/features/system/presentation/screens/notifications_screen.dart` | 47–122 | Hardcoded list `_allNotifications` of notification entries (ids 1 to 5). | Fetch user notifications from a notification repository. Manage read status updates back to the backend service. |
| `lib/features/system/presentation/screens/report_delete_confirm_screen.dart` | 45–46 | Hardcoded filter check: `report.id != 'report-golmok'`. | Pass the target `Report` model to be deleted as a parameter via context or route arguments. |
| `lib/features/system/presentation/screens/report_delete_confirm_screen.dart` | 56 & 136 | Hardcoded messages: `"골목밥상 제보를 삭제했어요."`, subtitle: `"골목밥상 · 제육덮밥 6,000원"`. | Render details dynamically based on the passed report item. |
| `lib/features/system/presentation/screens/search_empty_screen.dart` | 29–30, 368–373 | Hardcoded query: `_query = '주차요금'`, filters: `_filters = const ['음식점', '1만원 이하', '500m 이내']`, suggestion chips and widths. | Pass current filter lists and query states from the previous search page context. Pull recommendations from a dynamic trending-search service. |
| `lib/features/system/presentation/screens/session_expired_screen.dart` | 41 | Hardcoded reset email: `email: 'minseo@example.com'`. | Reset the auth state notifier dynamically without supplying hardcoded mock credentials. |

---

## 13. Feature: taegwan
- **Scan Results**: No mockup or dummy data was found in `lib/features/taegwan/presentation/widgets/taegwan_ui.dart`. All widgets and values in this feature are structural or component-level utilities.
