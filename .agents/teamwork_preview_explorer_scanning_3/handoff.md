# Handoff Report - Explorer 3

## 1. Observation
We scanned all Dart files across the assigned feature directories (`savings`, `search`, `store`, `system`, and `taegwan`) under `/Users/min/Documents/howmuch/lib/features/`. The following files were observed to contain hardcoded mockup data:
- `lib/features/store/presentation/screens/visit_verification_screen.dart` (Lines 76, 123, 128, 141, 325)
  - Line 123: `Text('착한분식', ...)`
  - Line 128: `Text('김치찌개 5,500원', ...)`
- `lib/features/store/presentation/screens/directions_external_app_screen.dart` (Lines 20-22, 27, 43, 154, 159, 173)
  - Line 27: `final query = Uri.encodeComponent('착한분식 서울시 강남구 역삼동');`
- `lib/features/store/presentation/screens/price_change_report_screen.dart` (Lines 23, 24, 162, 172, 179)
  - Line 162: `Text('동네카페', ...)`
- `lib/features/store/presentation/screens/price_history_screen.dart` (Lines 68, 80, 93-125, 178-211)
  - Line 68: `Text('착한분식 · 김치찌개', ...)`
- `lib/features/store/presentation/screens/review_list_screen.dart` (Lines 20-51, 99, 142, 146)
  - Line 99: `Text('착한분식', ...)`
- `lib/features/store/presentation/screens/review_write_screen.dart` (Lines 22, 23, 175, 180)
  - Line 175: `Text('착한분식', ...)`
- `lib/features/store/presentation/screens/store_detail_screen.dart` (Lines 173, 182, 189, 219, 227, 421, 422, 484, 500-515)
  - Line 227: `Text('2,000', ...)`
- `lib/features/store/presentation/screens/visit_verification_complete_screen.dart` (Lines 66, 82, 113, 121)
  - Line 113: `Text('착한분식', ...)`
- `lib/features/savings/presentation/screens/savings_detail_screen.dart` (Lines 40-85, 198, 225, 235)
  - Line 47: `storeName: '착한분식',`
- `lib/features/savings/presentation/screens/savings_goal_setting_screen.dart` (Lines 206-207, 216-217, 226-227)
  - Line 206: `current: '14,500원',`
- `lib/features/savings/presentation/screens/savings_report_dashboard_screen.dart` (Lines 197-200, 208, 212-215, 223, 227-231, 202-204, 217-219, 233-235, 205, 220, 236)
  - Line 197: `_buildBar(label: '1주', amount: '4,500원', height: 50, isMax: false),`
- `lib/features/savings/presentation/state/savings_state.dart` (Lines 9, 12)
  - Line 12: `final ValueNotifier<int> currentSaved = ValueNotifier<int>(24500);`
- `lib/features/search/presentation/screens/search_result_screen.dart` (Lines 221-273, 1039-1044)
  - Line 1040: `('김치찌개', 73.80681610107422),`
- `lib/features/system/presentation/screens/notifications_screen.dart` (Lines 47-122)
  - Line 59: `messageText: '찜한 동네카페의 아메리카노 가격이 2,000원으로 제보되었어요',`
- `lib/features/system/presentation/screens/report_delete_confirm_screen.dart` (Lines 45-46, 56, 136)
  - Line 136: `Text('골목밥상 · 제육덮밥 6,000원', ...)`
- `lib/features/system/presentation/screens/search_empty_screen.dart` (Lines 29, 30, 368-373)
  - Line 29: `String _query = '주차요금';`
- `lib/features/system/presentation/screens/session_expired_screen.dart` (Line 41)
  - Line 41: `email: 'minseo@example.com',`

No mockup data was observed in the `taegwan` feature directory.

## 2. Logic Chain
1. We utilized `find_by_name` to locate all Dart files within features `/lib/features/savings`, `search`, `store`, `system`, and `taegwan`.
2. We inspected each file using `view_file` to review UI screens, widgets, models, and state files.
3. For each file, we checked whether data elements (e.g. store names, menu items, prices, savings records, notifications, timeline updates) were hardcoded.
4. We documented the specific file path, lines, and hardcoded values, and proposed dynamic integrations (constructors, state providers, APIs).

## 3. Caveats
- We did not scan other feature directories (e.g., `admin`, `auth`, `community`, `errors`, `home`, `mypage`, `onboarding`) as they were out of scope.
- We assumed that values representing business rules (such as standard distance values like 500m / 1km / 3km in filter chips) are static config values rather than "mockup data" that need database integration.

## 4. Conclusion
Numerous screens and states across the scanned feature directories (`savings`, `search`, `store`, `system`) rely on hardcoded mock values (e.g., store name "착한분식", menu items, savings amounts, notifications) for presentation. These files need to be refactored to accept model arguments or hook into Riverpod/ValueNotifier state providers to load dynamic backend/local DB data.

## 5. Verification Method
Inspect the report generated at `/Users/min/Documents/howmuch/.agents/teamwork_preview_explorer_scanning_3/analysis.md` and check the corresponding line numbers and files.
Command to verify the project builds and runs tests (if applicable):
`flutter test` in `/Users/min/Documents/howmuch/`
*(Note: As Explorer 3 has read-only access, no source code modification was performed).*
