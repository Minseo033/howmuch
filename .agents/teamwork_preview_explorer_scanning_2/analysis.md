# Hardcoded Mockup Data Scanning Analysis Report

This report documents findings from a comprehensive scan of Dart files under `lib/features/mypage/`, `lib/features/onboarding/`, and `lib/features/recommendation/` for hardcoded mockup data.

---

## Summary of Findings
- **`lib/features/recommendation/`**: Features multiple screens (Optimal Route, AI Chat, Today's Pick) containing hardcoded mockup UI structures, mock map locations, static weather metrics, and hardcoded backend ngrok endpoint configurations.
- **`lib/features/mypage/`**: Features extensive use of local state mocking in providers (`mypage_state.dart`) as well as in-UI hardcoded mockup lists (My Reviews, Visit History) and static warnings (Withdrawal screen counts).
- **`lib/features/onboarding/`**: Primarily contains static slide assets and onboarding illustrations. These are static by design but could be localized.

---

## Detailed Findings & Recommendations

### 1. Recommendation Feature (`lib/features/recommendation/`)

#### A. Optimal Route Screen
- **File Path**: `lib/features/recommendation/presentation/screens/optimal_route_screen.dart`
- **Line Numbers**: 95–153, 168–178, 189–260
- **Hardcoded Content**:
  - **Mock Map Markers (Lines 95-153)**: Hardcoded layout offsets and text labels (`1 착한분식`, `2 동네카페`) representing route locations on a dummy map.
  - **Route Steps (Lines 168-178)**: Hardcoded calls to `_buildRouteStep` and `_buildConnection` arguments:
    - Step 1: `storeName: '착한분식'`, `details: '김치찌개 5,500원 · 320m'`
    - Connection: `'도보 6분'`
    - Step 2: `storeName: '동네카페'`, `details: '아메리카노 2,000원 · 500m'`
  - **Summary Card Values (Lines 189-260)**: Hardcoded cost metrics, savings, and route path attributes:
    - Total cost: `'7,500원'`
    - Total savings: `'약 4,300원'`
    - Total distance: `'총 820m'`
    - Total estimated time: `'예상 소요 12분'`
- **Recommendations for Dynamic Integration**:
  - Define `OptimalRoute`, `RouteStep`, and `RoutePath` models.
  - Introduce an `optimalRouteProvider` to fetch recommended path details dynamically based on coordinates or chosen stores.
  - Convert `OptimalRouteScreen` to a `ConsumerWidget` to watch this provider and generate steps/summary metrics dynamically.

#### B. AI Recommend Chat Screen
- **File Path**: `lib/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart`
- **Line Numbers**: 27–35, 469–478
- **Hardcoded Content**:
  - **Quick Prompts (Lines 27-35)**: Static lists of label prompt strings (e.g. `'만원 이하 점심 추천'`, `'비 오는 날 따뜻한 국물'`, `'혼밥하기 좋은 분식'`, `'이 근처 오후 코스 짜줘'`).
  - **Greeting Message (Lines 469-478)**: Hardcoded text in `_GreetingBubble` using generic `'고객님'` name placeholder.
- **Recommendations for Dynamic Integration**:
  - Load quick prompts from a configuration service (e.g. remote configurations) or API response, potentially sorting by local time/weather.
  - Interpolate the current authenticated user's nickname from `userProfileProvider` in the greeting bubble.

#### C. AI Chat Service
- **File Path**: `lib/features/recommendation/presentation/state/ai_chat_service.dart`
- **Line Numbers**: 9, 12
- **Hardcoded Content**:
  - **Backend Host (Line 9)**: Unused configuration `_backendHost` IP.
  - **Endpoint URL (Line 12)**: Hardcoded ngrok endpoint URL (`https://sulfurously-transhumant-dennise.ngrok-free.dev/api/ai/chat`).
- **Recommendations for Dynamic Integration**:
  - Fetch base URL / API endpoint from environment variables (`String.fromEnvironment`) or an app-level configuration provider.

#### D. Today's Pick Screen
- **File Path**: `lib/features/recommendation/presentation/screens/todays_pick_screen.dart`
- **Line Numbers**: 42–91, 187, 202, 216, 238
- **Hardcoded Content**:
  - **Mock Items list (Lines 42-91)**: Static `_allItems` list containing 4 hardcoded items ("착한칼국수", "골목국밥", "정다운분식", "초가집삼계탕") with static prices, distances, and tags.
  - **Weather Details (Lines 187, 202, 216, 238)**: Hardcoded card parameters:
    - Date: `'2026.05.16 (토)'`
    - Weather comment: `'비가 오는 날이네요 ☔️'`
    - Temperature: `'18°'`
    - Recommendation: `'🍜 따뜻한 국물 메뉴를 추천해요'`
- **Recommendations for Dynamic Integration**:
  - Integrate a Weather API/Service Provider (`weatherProvider`) to fetch live location weather, temperature, and matching dates.
  - Replace the static `_allItems` list with a `todaysPickProvider` fetching recommendations from the backend server based on user's location, preferences, and weather conditions.

---

### 2. MyPage Feature (`lib/features/mypage/`)

#### A. MyPage State
- **File Path**: `lib/features/mypage/presentation/state/mypage_state.dart`
- **Line Numbers**: 317–331, 351–375, 377–412, 415–473
- **Hardcoded Content**:
  - **User Profile (Lines 317-331)**: Hardcoded initialization of `userProfileProvider` mock values (nickname: `'절약왕 민서'`, saved amount: `24500`, etc.).
  - **Price Alert Subscriptions (Lines 351-375)**: Static stores ("착한분식", "동네카페", "착한미용실").
  - **Social Accounts (Lines 377-412)**: Hardcoded linked account records with hardcoded dates (`2025.10.04`, `2026.02.18`).
  - **Favorite Stores (Lines 415-473)**: Mock stores list for favorite stores list.
- **Recommendations for Dynamic Integration**:
  - Connect these providers to repositories that perform actual API requests (e.g. `UserProfileApiService`).
  - Use dynamic credentials from `authStateProvider` to pull authenticated user profile records from the database instead of hardcoding dummy models.

#### B. MyPage Screen
- **File Path**: `lib/features/mypage/presentation/screens/mypage_screen.dart`
- **Line Numbers**: 167
- **Hardcoded Content**:
  - **Admin Mode Toggle (Line 167)**: Temporary local developer state override.
- **Recommendations for Dynamic Integration**:
  - Implement dynamic admin privilege verification by checking user role/permissions against auth state properties or backend verification endpoint metadata.

#### C. Account Management Screen
- **File Path**: `lib/features/mypage/presentation/screens/account_management_screen.dart`
- **Line Numbers**: 297–302
- **Hardcoded Content**:
  - **Location Permission Text (Lines 297-302)**: Hardcoded value `'허용'` for location usage.
- **Recommendations for Dynamic Integration**:
  - Check the application location permission status dynamically using a permission state controller/provider.

#### D. Inquiry Screen
- **File Path**: `lib/features/mypage/presentation/screens/inquiry_screen.dart`
- **Line Numbers**: 46–50
- **Hardcoded Content**:
  - **Text Controllers (Lines 46-50)**: Initialized default value strings in text controllers:
    - Title: `'착한분식 가격이 변경된 것 같아요'`
    - Body: `'지난 주에 방문했을 때 김치찌개가 6,000원이었어요.\n가격 확인 부탁드립니다.'`
- **Recommendations for Dynamic Integration**:
  - Clear the initial controller strings to leave fields empty by default. Add these strings as placeholders using `hintText` in `InputDecoration`.

#### E. My Reviews Screen
- **File Path**: `lib/features/mypage/presentation/screens/my_reviews_screen.dart`
- **Line Numbers**: 12–40, 155
- **Hardcoded Content**:
  - **Reviews List (Lines 12-40)**: Dummy reviews list defined inside the `build` method ("착한분식", "동네카페", "착한미용실").
  - **Average Rating (Line 155)**: Hardcoded text `'4.7'`.
- **Recommendations for Dynamic Integration**:
  - Fetch reviews written by the active user from an API provider (e.g. `userReviewsProvider`).
  - Calculate average ratings dynamically based on reviews list metrics.

#### F. Notification Settings Screen
- **File Path**: `lib/features/mypage/presentation/screens/notification_settings_screen.dart`
- **Line Numbers**: 434
- **Hardcoded Content**:
  - **Subscription Summary Subtitle (Line 434)**: Hardcoded summary text `'매장 3곳 · 메뉴 5개 관리'`.
- **Recommendations for Dynamic Integration**:
  - Derive this count dynamically from active sub-elements inside `priceAlertSettingsProvider`.

#### G. Visit History Screen
- **File Path**: `lib/features/mypage/presentation/screens/visit_history_screen.dart`
- **Line Numbers**: 13–50, 66, 116, 136
- **Hardcoded Content**:
  - **Visit Items List (Lines 13-50)**: Mock visits array inside the `build` method.
  - **Total Count (Line 66)**: Hardcoded value `'4'`.
  - **Monthly Visits Count (Line 116)**: Hardcoded value `'6'`.
  - **Monthly Savings (Line 136)**: Hardcoded value `'24,500원'`.
- **Recommendations for Dynamic Integration**:
  - Setup a `visitHistoryProvider` to fetch history from the backend.
  - Compute total visits, monthly visits, and monthly savings dynamically from the fetched visit list.

#### H. Withdrawal Screen
- **File Path**: `lib/features/mypage/presentation/screens/withdrawal_screen.dart`
- **Line Numbers**: 320–324
- **Hardcoded Content**:
  - **Warning Summary Data (Lines 320-324)**: Hardcoded user count values showing `'2건'`, `'12곳'`, `'24,500원 누적'`, `'7개'`, `'5개 메뉴'`.
- **Recommendations for Dynamic Integration**:
  - Dynamically read these metrics from active providers (e.g. `userProfileProvider`, `favoriteStoresProvider`, etc.) to show exact, real-time context-specific warnings.

#### I. User Profile API Service
- **File Path**: `lib/features/mypage/presentation/state/user_profile_api_service.dart`
- **Line Numbers**: 6–8
- **Hardcoded Content**:
  - **Base URL (Lines 6-8)**: Hardcoded ngrok endpoint URL (`https://sulfurously-transhumant-dennise.ngrok-free.dev`).
- **Recommendations for Dynamic Integration**:
  - Externalize URL endpoints into global app configs/environment variables.

---

### 3. Onboarding Feature (`lib/features/onboarding/`)
- **Observations**:
  - Slide data descriptions and artwork placeholders (e.g. `'내 주변 착한가격업소를 한눈에'`, price labels in painters) are static content elements.
- **Assessment**:
  - These are typical static UI illustrations rather than mockup data that requires dynamic API integration. However, internationalization (i18n) can be added via ARB files if localized strings are needed.
