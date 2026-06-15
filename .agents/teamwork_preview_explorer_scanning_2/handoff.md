# Handoff Report — Explorer 2

## 1. Observation
I directly scanned the files in the assigned directories (`mypage`, `onboarding`, and `recommendation`) and observed the following hardcoded mock data structures:

* **File**: `lib/features/recommendation/presentation/screens/optimal_route_screen.dart`
  * **Lines 168–178**:
    ```dart
    _buildRouteStep(
      index: '1',
      storeName: '착한분식',
      details: '김치찌개 5,500원 · 320m',
    ),
    _buildConnection('도보 6분'),
    _buildRouteStep(
      index: '2',
      storeName: '동네카페',
      details: '아메리카노 2,000원 · 500m',
    ),
    ```
* **File**: `lib/features/recommendation/presentation/screens/todays_pick_screen.dart`
  * **Lines 42–91**:
    ```dart
    final List<TodaysPickItem> _allItems = [
      TodaysPickItem(
        id: '1',
        storeName: '착한칼국수',
        menuName: '칼국수',
        price: '5,000원',
        tipText: '💡 비 오는 날 인기 메뉴',
        distance: '450m',
        badgeText: '정부 인증',
        ...
    ```
* **File**: `lib/features/mypage/presentation/state/mypage_state.dart`
  * **Lines 317–331**:
    ```dart
    // TODO(박지환 BE): 사용자 프로필 API 응답으로 교체하세요.
    final userProfileProvider = StateProvider<UserProfile>(
      (ref) => const UserProfile(
        nickname: '절약왕 민서',
        email: 'minseo@email.com',
        level: 'LV.3 절약러',
        region: '서울시 강남구 역삼동',
        ...
    ```
* **File**: `lib/features/mypage/presentation/screens/my_reviews_screen.dart`
  * **Lines 12–40**:
    ```dart
    // TODO(박지환 BE): 내 리뷰 내역 및 총 개수, 평균 별점 연동
    final reviews = [
      {
        'isGov': true,
        'name': '착한분식',
        'date': '2026.05.10',
        'rating': 5,
        'visitedMenu': '김치찌개',
        'content': '가격이 저렴하고 양이 많아요. 재방문 의사 100%!',
        'likes': 24,
      },
      ...
    ```
* **File**: `lib/features/mypage/presentation/screens/visit_history_screen.dart`
  * **Lines 13–50**:
    ```dart
    // TODO(박지환 BE): 방문 기록 및 누적 절약 금액 연동
    final items = [
      {
        'isGov': true,
        'name': '착한분식',
        'menu': '김치찌개',
        'price': '5,500원',
        'saving': '2,000원 절약',
        ...
    ```
* **File**: `lib/features/mypage/presentation/state/user_profile_api_service.dart`
  * **Lines 6–8**:
    ```dart
    static const String _backendBaseUrl = kIsWeb
        ? 'http://localhost:8081'
        : 'https://sulfurously-transhumant-dennise.ngrok-free.dev';
    ```

Full details are documented in `analysis.md` inside this directory.

## 2. Logic Chain
1. During the search phase, I checked the file structure under `/Users/min/Documents/howmuch/lib/features/` and located all files within the target directories.
2. Grepping and viewing these files revealed that several state providers are initialized with mockup objects containing names like `'절약왕 민서'`, and several screen widgets define local mockup arrays (e.g. `reviews`, `items`, `_allItems`) directly inside their build methods.
3. Hardcoded backend API URLs (such as the ngrok endpoint) were also discovered in `user_profile_api_service.dart` and `ai_chat_service.dart`.
4. Therefore, I conclude that these mock values and configurations need to be replaced with dynamic integrations (such as actual service/repository network calls and environment variables).

## 3. Caveats
- Onboarding artwork displays visual/static charts (e.g. `'24,500'` monthly savings illustration). I assumed these are part of the static design elements and do not require dynamic backend integration unless translation/localization is required later.
- This was a read-only investigation, and no code execution was performed to test dynamic injection of these configurations.

## 4. Conclusion
The codebase contains several instances of hardcoded mockup data in both state providers and UI build methods, alongside hardcoded ngrok tunnel backend base URLs. These must be refactored to fetch dynamic data from providers/repositories and environment configurations.

## 5. Verification Method
- **Verify findings**: Inspect the files at the specific line numbers mentioned in `analysis.md` using `view_file`.
- **Invalidation condition**: If a developer updates these files to use actual backend APIs and retrieves environment variables dynamically, this analysis will become obsolete.
