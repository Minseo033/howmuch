# Hardcoded Mockup Data Analysis Report

This report documents the hardcoded mockup data found during the read-only scan of the assigned features (`savings`, `search`, `store`, `system`, and `taegwan`) in the `howmuch` codebase under `/lib/features/`.

---

## 1. Feature: `store`

### A. Visit Verification Screen (`visit_verification_screen.dart`)
* **File Path:** `lib/features/store/presentation/screens/visit_verification_screen.dart`
* **Hardcoded Content/Values:**
  * Line 76: `"매장 근처에 있을 때 인증할 수 있어요. 현재 거리: 320m"` (Hardcoded distance text)
  * Line 123: `"착한분식"` (Hardcoded store name)
  * Line 128: `"김치찌개 5,500원"` (Hardcoded menu and price info)
  * Line 141: `"320m"` (Hardcoded distance badge)
  * Line 325: `"약 2,000원 절약"` (Hardcoded expected savings amount)
* **Recommendations for Dynamic Integration:**
  * Accept a `Store` object or a `storeId` string in the widget constructor.
  * Initialize details from a `storeProvider` or pass arguments using `go_router` extra parameters.
  * Compute distance dynamically using a geolocator service compared with the store's lat/lng coordinates.
  * Compute expected savings by comparing the store's price with the neighborhood average price, retrieved via a price average API.

### B. Directions External App Screen (`directions_external_app_screen.dart`)
* **File Path:** `lib/features/store/presentation/screens/directions_external_app_screen.dart`
* **Hardcoded Content/Values:**
  * Lines 20–22: Hardcoded transport travel times in `_transports` list (`"6분"`, `"10분"`, `"4분"`).
  * Line 27: `"착한분식 서울시 강남구 역삼동"` (Query string for Kakao map launcher)
  * Line 43: `"착한분식 서울시 강남구 역삼동"` (Query string for Naver map launcher)
  * Line 154: `"착한분식"` (Hardcoded store name)
  * Line 159: `"서울시 강남구 역삼동"` (Hardcoded address)
  * Line 173: `"320m"` (Hardcoded distance badge)
* **Recommendations for Dynamic Integration:**
  * Pass the current `Store` object to the screen.
  * Construct map queries dynamically: `"${store.storeName} ${store.address}"`.
  * Calculate travel times using the Google/Naver Directions API or by launching the external map applications directly with coordinates.

### C. Price Change Report Screen (`price_change_report_screen.dart`)
* **File Path:** `lib/features/store/presentation/screens/price_change_report_screen.dart`
* **Hardcoded Content/Values:**
  * Line 23: `TextEditingController(text: '아메리카노')` (Hardcoded pre-populated menu name)
  * Line 24: `TextEditingController(text: '2,500')` (Hardcoded pre-populated menu price)
  * Line 162: `"동네카페"` (Hardcoded store name)
  * Line 172: `"아메리카노"` (Hardcoded existing menu name label)
  * Line 179: `"2,000원"` (Hardcoded existing price label)
* **Recommendations for Dynamic Integration:**
  * Accept `Store` and `Menu` parameters to pre-fill the form controllers dynamically.
  * Bind existing store details and menu details using widget state arguments.

### D. Price History Screen (`price_history_screen.dart`)
* **File Path:** `lib/features/store/presentation/screens/price_history_screen.dart`
* **Hardcoded Content/Values:**
  * Line 68: `"착한분식 · 김치찌개"` (Hardcoded store and menu title)
  * Line 80: `"5,500원"` (Hardcoded current registered price)
  * Lines 93–125: Hardcoded bar height coefficients and labels in `_buildBarChart()` (e.g. `"2025.06"`, `"5,500원 (현재)"`, `"5,000원 (이전)"`).
  * Lines 178–211: Hardcoded timeline list items representing past price updates.
* **Recommendations for Dynamic Integration:**
  * Fetch price history logs from a repository/API using `storeId` and `menuId`.
  * Represent history as a list of data transfer objects (DTOs) and bind them to the bar chart heights and timeline builder dynamically.

### E. Review List Screen (`review_list_screen.dart`)
* **File Path:** `lib/features/store/presentation/screens/review_list_screen.dart`
* **Hardcoded Content/Values:**
  * Lines 20–51: Hardcoded mock reviews array `_reviews` containing names, ratings, contents, and replies.
  * Line 99: `"착한분식"` (Hardcoded store name)
  * Line 142: `"4.8"` (Hardcoded store average rating)
  * Line 146: `" · 리뷰 128"` (Hardcoded review count)
* **Recommendations for Dynamic Integration:**
  * Connect to a `reviewsProvider` or similar service to fetch reviews dynamically based on `storeId`.
  * Calculate average rating and total counts from the fetched database payload.

### F. Review Write Screen (`review_write_screen.dart`)
* **File Path:** `lib/features/store/presentation/screens/review_write_screen.dart`
* **Hardcoded Content/Values:**
  * Line 22: `TextEditingController(text: '김치찌개')` (Hardcoded pre-populated menu)
  * Line 23: `TextEditingController(text: '5,500')` (Hardcoded pre-populated price)
  * Line 175: `"착한분식"` (Hardcoded store name)
  * Line 180: `"서울 강남구 역삼동"` (Hardcoded address)
* **Recommendations for Dynamic Integration:**
  * Bind inputs dynamically based on the current context passed via widget construction (e.g. from the store detail page).

### G. Store Detail Screen (`store_detail_screen.dart`)
* **File Path:** `lib/features/store/presentation/screens/store_detail_screen.dart`
* **Hardcoded Content/Values:**
  * Line 173: `"4.6"` (Hardcoded mock average rating)
  * Line 182: `"리뷰 128"` (Hardcoded review count)
  * Line 189: `_MockTag('목업')` (Mock tag badge)
  * Line 219: `_MockTag('목업 - 추후 개발 필요')` (Mock expected savings label)
  * Line 227: `"2,000"` (Hardcoded savings amount)
  * Line 421: `"정보 없음"` (Hardcoded business hours placeholder)
  * Line 422: `isMock: true` (Hardcoded mock flag for business hours)
  * Line 484: `_MockTag('목업 - 추후 개발 필요')` (Mock badge for review header)
  * Lines 500–515: Hardcoded mock reviews for `김○○` and `이○○`.
* **Recommendations for Dynamic Integration:**
  * Update the `Store` model to support fields like `rating`, `reviewCount`, `businessHours`, and `expectedSavings`.
  * Fetch real user reviews using a Riverpod or Provider state notifier for the store reviews tab.

### H. Visit Verification Complete Screen (`visit_verification_complete_screen.dart`)
* **File Path:** `lib/features/store/presentation/screens/visit_verification_complete_screen.dart`
* **Hardcoded Content/Values:**
  * Line 66: `"2,000원"` (Hardcoded current savings)
  * Line 82: `"26,500원"` (Hardcoded monthly accumulated savings)
  * Line 113: `"착한분식"` (Hardcoded store name)
  * Line 121: `"김치찌개 5,500원"` (Hardcoded menu and price info)
* **Recommendations for Dynamic Integration:**
  * Pass the completed verification transaction details (saved amount, store details, cumulative savings) as arguments when navigating to this screen.

---

## 2. Feature: `savings`

### A. Savings Detail Screen (`savings_detail_screen.dart`)
* **File Path:** `lib/features/savings/presentation/screens/savings_detail_screen.dart`
* **Hardcoded Content/Values:**
  * Lines 40–85: `_allItems` contains a hardcoded array of `SavingsDetailItem` structures.
  * Line 198: `"24,500"` (Hardcoded total monthly savings)
  * Line 225: `"📍 6회 방문"` (Hardcoded monthly visit count badge)
  * Line 235: `"· 평균 4,083원 절약"` (Hardcoded monthly average savings badge)
* **Recommendations for Dynamic Integration:**
  * Fetch savings records using a database/repository provider (e.g. `savingsHistoryProvider`).
  * Calculate monthly totals, visit frequency, and average savings programmatically from the retrieved dataset.

### B. Savings Goal Setting Screen (`savings_goal_setting_screen.dart`)
* **File Path:** `lib/features/savings/presentation/screens/savings_goal_setting_screen.dart`
* **Hardcoded Content/Values:**
  * Lines 206–207: `"14,500원"`, `" / 20,000원"` (Hardcoded progress values for "음식점")
  * Lines 216–217: `"6,500원"`, `" / 8,000원"` (Hardcoded progress values for "카페")
  * Lines 226–227: `"3,500원"`, `" / 5,000원"` (Hardcoded progress values for "생활서비스")
* **Recommendations for Dynamic Integration:**
  * Query category-specific limits and achievements from a settings or profile database.
  * Bind these fields to reactive states or category progress providers.

### C. Savings Report Dashboard Screen (`savings_report_dashboard_screen.dart`)
* **File Path:** `lib/features/savings/presentation/screens/savings_report_dashboard_screen.dart`
* **Hardcoded Content/Values:**
  * Lines 197–200, 208, 212–215, 223, 227–231: Hardcoded weekly and monthly bar chart stats for different tab periods ("이번 달", "지난 달", "올해").
  * Lines 202–204, 217–219, 233–235: Hardcoded visit, favorite, and report counts.
  * Lines 205, 220, 236: Hardcoded recommendations subheadings.
* **Recommendations for Dynamic Integration:**
  * Feed chart bars and dashboard metrics from a dashboard stats service that groups records based on the selected timeframe.

### D. Savings Global State (`savings_state.dart`)
* **File Path:** `lib/features/savings/presentation/state/savings_state.dart`
* **Hardcoded Content/Values:**
  * Line 9: `ValueNotifier<int>(30000)` (Hardcoded initial goal)
  * Line 12: `ValueNotifier<int>(24500)` (Hardcoded initial achievement rate)
* **Recommendations for Dynamic Integration:**
  * Retrieve these states from local preferences/secure storage during initialization, fallback to defaults if empty.

---

## 3. Feature: `search`

### A. Search Result Screen (`search_result_screen.dart`)
* **File Path:** `lib/features/search/presentation/screens/search_result_screen.dart`
* **Hardcoded Content/Values:**
  * Lines 221–273: `_mockResults(String q)` contains fallback mock lists of stores.
  * Lines 1039–1044: Hardcoded search suggestion tags (e.g. `'김치찌개'`, `'아메리카노'`) and hardcoded chip widths (e.g. `73.80681610107422`).
* **Recommendations for Dynamic Integration:**
  * Fetch recommendation terms from a trending-search API.
  * Dynamically calculate chip sizing or use standard Flutter `Wrap` flow layouts without fixed widths.

---

## 4. Feature: `system`

### A. Notifications Screen (`notifications_screen.dart`)
* **File Path:** `lib/features/system/presentation/screens/notifications_screen.dart`
* **Hardcoded Content/Values:**
  * Lines 47–122: `_allNotifications` has hardcoded notification entries (ids 1 to 5).
* **Recommendations for Dynamic Integration:**
  * Fetch user notifications from a notification repository.
  * Manage read status updates back to the backend service.

### B. Report Delete Confirm Screen (`report_delete_confirm_screen.dart`)
* **File Path:** `lib/features/system/presentation/screens/report_delete_confirm_screen.dart`
* **Hardcoded Content/Values:**
  * Lines 45–46: `report.id != 'report-golmok'` (Mock filter query ID)
  * Line 56: `"골목밥상 제보를 삭제했어요."` (Hardcoded snackbar description)
  * Line 136: `"골목밥상 · 제육덮밥 6,000원"` (Hardcoded dialog subtitle text)
* **Recommendations for Dynamic Integration:**
  * Pass the target `Report` model to be deleted as a parameter via context or route arguments.
  * Render details dynamically based on the passed report item.

### C. Search Empty Screen (`search_empty_screen.dart`)
* **File Path:** `lib/features/system/presentation/screens/search_empty_screen.dart`
* **Hardcoded Content/Values:**
  * Line 29: `_query = '주차요금'` (Hardcoded query placeholder)
  * Line 30: `_filters = const ['음식점', '1만원 이하', '500m 이내']` (Hardcoded filters array)
  * Lines 368–373: Hardcoded suggestion chips (e.g. `'김치찌개'`, `'아메리카노'`) and hardcoded chip widths.
* **Recommendations for Dynamic Integration:**
  * Pass current filter lists and query states from the previous search page context.
  * Pull recommendations from a dynamic trending-search service.

### D. Session Expired Screen (`session_expired_screen.dart`)
* **File Path:** `lib/features/system/presentation/screens/session_expired_screen.dart`
* **Hardcoded Content/Values:**
  * Line 41: `email: 'minseo@example.com'` (Hardcoded email mock used during authentication reset)
* **Recommendations for Dynamic Integration:**
  * Reset the auth state notifier dynamically without supplying hardcoded mock credentials.

---

## 5. Feature: `taegwan`
* **Scan Results:** No mockup or dummy data was found in `lib/features/taegwan/presentation/widgets/taegwan_ui.dart`. All widgets and values in this feature are structural or component-level utilities.
