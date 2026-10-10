import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/todays_pick_screen.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_failure.dart';
import 'package:howmuch/features/recommendation/presentation/state/todays_pick_service.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/recommendation_radius_button.dart';
import 'package:howmuch/features/search/presentation/screens/search_filter_screen.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/store/presentation/screens/directions_external_app_screen.dart';
import 'package:howmuch/features/store/presentation/screens/store_detail_screen.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/shared/widgets/choice_semantics.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_reader.dart';

/// QA 2026-10-07 screen reader items in the shared widgets, search,
/// recommendation and store screens (#50, #52, #54).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HomeMapScreen.setSearchCatalog([
      _store('near', '다 시청 칼국수', '5,000', 37.5663, 126.9779),
    ]);
    HomeMapScreen.globalUserPosition = _position(37.5665, 126.9780);
  });

  tearDown(() {
    HomeMapScreen.setSearchCatalog(const []);
    HomeMapScreen.globalUserPosition = null;
    ChoiceSemantics.debugIsWebOverride = null;
  });

  group('selection state (#52)', () {
    testWidgets('the radius slider reads the distance and steps it by 1km', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openRadiusSheet(tester);

      // One element names the setting and says the picked distance, and a
      // screen reader swipe moves it one stop either way.
      expect(_radiusSlider(), findsOne);
      expect(
        _radiusSlider(),
        isSemantics(
          isSlider: true,
          label: '추천 거리',
          value: '3km 이내',
          increasedValue: '4km 이내',
          decreasedValue: '2km 이내',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );

      tester.semantics.increase(_radiusSlider());
      await tester.pumpAndSettle();
      expect(_radiusSlider(), isSemantics(value: '4km 이내'));
      expect(readerElements('4km 이내로 적용하기'), findsOne);
      semantics.dispose();
    });

    testWidgets('the radius sheet stays in the app column on a wide window', (
      tester,
    ) async {
      _setViewport(tester, const Size(1424, 900));
      await _openRadiusSheet(tester);

      // The sheet's surface, inside the full-width BottomSheet alignment.
      final sheet = tester.getRect(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(sheet.width, lessThanOrEqualTo(430));
      expect(sheet.center.dx, closeTo(712, .1));
    });

    for (final web in [false, true]) {
      final platform = web ? 'web' : 'app';
      testWidgets('filter chips and switches read their state ($platform)', (
        tester,
      ) async {
        ChoiceSemantics.debugIsWebOverride = web;
        final semantics = tester.ensureSemantics();
        await _openFilterSheet(
          tester,
          const SearchFilter(
            maxPrice: 5000,
            sortOrder: '저렴한순',
            govCertified: true,
            userReported: false,
          ),
        );

        for (final (chip, picked) in [
          ('전체', true),
          ('카페', false),
          ('5,000원 이하', true),
          ('10,000원 이하', false),
          ('저렴한순', true),
          ('가까운순', false),
        ]) {
          expect(readerElements(chip), findsOne, reason: chip);
          expect(
            readerElements(chip),
            isSemantics(
              isButton: true,
              hasTapAction: true,
              isSelected: web ? null : picked,
              isChecked: web ? picked : null,
              // Chips can be turned off again, so they are not radios.
              isInMutuallyExclusiveGroup: false,
            ),
            reason: chip,
          );
        }
        for (final (name, on) in [
          ('정부 인증 업소만 보기', true),
          ('사용자 제보 매장 포함', false),
        ]) {
          expect(readerElements(name), findsOne, reason: name);
          expect(
            readerElements(name),
            isSemantics(
              hasToggledState: true,
              isToggled: on,
              hasTapAction: true,
            ),
            reason: name,
          );
        }
        semantics.dispose();
      });
    }

    testWidgets('a chip announces its new state after a tap', (tester) async {
      final semantics = tester.ensureSemantics();
      await _openFilterSheet(tester, const SearchFilter());

      expect(readerElements('카페'), isSemantics(isSelected: false));
      tester.semantics.tap(readerElements('카페'));
      await tester.pumpAndSettle();
      expect(readerElements('카페'), isSemantics(isSelected: true));
      expect(readerElements('전체'), isSemantics(isSelected: false));

      tester.semantics.tap(readerElements('사용자 제보 매장 포함'));
      await tester.pumpAndSettle();
      expect(readerElements('사용자 제보 매장 포함'), isSemantics(isToggled: false));
      semantics.dispose();
    });

    for (final web in [false, true]) {
      final platform = web ? 'web' : 'app';
      testWidgets('directions read the picked travel mode once ($platform)', (
        tester,
      ) async {
        ChoiceSemantics.debugIsWebOverride = web;
        final semantics = tester.ensureSemantics();
        await _openDirections(tester);

        for (final (mode, picked) in [
          ('도보 이동 방식', true),
          ('대중교통 이동 방식', false),
          ('자동차 이동 방식', false),
        ]) {
          final element = readerElements(mode);
          expect(element, findsOne, reason: mode);
          expect(spokenName(element.evaluate().single), mode);
          expect(
            element,
            isSemantics(
              isButton: true,
              hasTapAction: true,
              isSelected: web ? null : picked,
              isChecked: web ? picked : null,
              isInMutuallyExclusiveGroup: web ? true : null,
            ),
            reason: mode,
          );
        }

        tester.semantics.tap(readerElements('대중교통 이동 방식'));
        await tester.pumpAndSettle();
        expect(
          readerElements('대중교통 이동 방식'),
          isSemantics(
            isSelected: web ? null : true,
            isChecked: web ? true : null,
          ),
        );
        semantics.dispose();
      });
    }
  });

  group('names and roles (#50, #51)', () {
    testWidgets('the filter sheet close button has a name and closes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openFilterSheet(tester, const SearchFilter());

      final close = readerElements('검색 필터 닫기');
      expect(close, findsOne);
      expect(close, isSemantics(isButton: true, hasTapAction: true));
      tester.semantics.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(SearchFilterSheet), findsNothing);
      semantics.dispose();
    });

    testWidgets('directions read the back and map buttons once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openDirections(tester);

      expect(readerElements('뒤로가기'), findsOne);
      for (final app in ['네이버지도에서 열기', '카카오맵에서 열기']) {
        final element = readerElements(app);
        expect(element, findsOne, reason: app);
        expect(spokenName(element.evaluate().single), app);
        expect(element, isSemantics(isButton: true, hasTapAction: true));
      }
      semantics.dispose();
    });

    testWidgets('the search back button has a name', (tester) async {
      final semantics = tester.ensureSemantics();
      await _openSearch(tester);

      expect(readerElements('뒤로가기'), findsOne);
      expect(
        readerElements('뒤로가기'),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('the AI chat back button has a name', (tester) async {
      final semantics = tester.ensureSemantics();
      await _openAiChat(tester);

      expect(readerElements('뒤로가기'), findsOne);
      expect(
        readerElements('뒤로가기'),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('the AI chat field keeps its name without a floating label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openAiChat(tester);

      // Read as the field's name, not drawn as a label cut into the outline.
      expect(find.text('AI에게 질문'), findsNothing);
      expect(readerElements('AI에게 질문'), findsOne);
      expect(readerElements('AI에게 질문'), isSemantics(isTextField: true));

      await tester.enterText(find.byType(TextField), '근처 백반집');
      await tester.pump();
      expect(
        readerElements('AI에게 질문'),
        isSemantics(isTextField: true, value: '근처 백반집'),
      );
      semantics.dispose();
    });

    testWidgets('bottom tabs are named once', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: HowmuchBottomNav.heightFor(0),
                child: const HowmuchBottomNav(safeBottom: 0),
              ),
            ),
          ),
        ),
      );

      for (final tab in ['홈', '탐색', '제보', '리포트', '마이']) {
        // Not '홈 탭, 홈'.
        expect(readerElements(tab), findsOne, reason: tab);
        expect(
          readerElementsNamed('$tab 탭'),
          isSemantics(isButton: true, hasTapAction: true),
          reason: tab,
        );
      }
      expect(readerElementsNamed('홈 탭'), isSemantics(isSelected: true));
      semantics.dispose();
    });
  });

  group('buttons read as buttons (#54)', () {
    testWidgets('a search result card is a button named from the store', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openSearch(tester);

      final card = readerElements('다 시청 칼국수');
      expect(card, findsOne);
      expect(card, isSemantics(isButton: true, hasTapAction: true));
      final name = spokenName(card.evaluate().single);
      expect(name, startsWith('다 시청 칼국수'));
      expect(name, contains('5,000원'));
      expect(readerElements('🍲'), findsNothing);

      tester.semantics.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('상세 화면'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('closing the keyboard is not a tap on the whole screen', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openSearch(tester);

      expect(readerElements('검색 결과'), findsOne);
      expect(readerElements('검색 결과'), isSemantics(hasTapAction: false));
      semantics.dispose();
    });

    testWidgets('an active filter chip is a button that removes it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openSearch(tester, filter: const SearchFilter(maxPrice: 5000));

      final chip = readerElementsNamed('5,000원 이하 필터 해제');
      expect(chip, findsOne);
      expect(chip, isSemantics(isButton: true, hasTapAction: true));
      tester.semantics.tap(chip);
      await tester.pumpAndSettle();
      expect(readerElementsNamed('5,000원 이하 필터 해제'), findsNothing);
      semantics.dispose();
    });

    testWidgets('AI question chips are buttons', (tester) async {
      final semantics = tester.ensureSemantics();
      await _openAiChat(tester);

      for (final prompt in [
        '10,000원 이하 점심',
        '비 오는 날 국물',
        '혼밥 분식 추천',
        '근처 오후 코스',
      ]) {
        expect(readerElementsNamed(prompt), findsOne, reason: prompt);
        expect(
          readerElementsNamed(prompt),
          isSemantics(isButton: true, hasTapAction: true),
          reason: prompt,
        );
      }
      semantics.dispose();
    });

    testWidgets('AI answer store cards are read apart from the answer', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openAiChat(tester, withAnswer: true);

      for (final (store, details) in [
        ('미락칼국수', ['칼국수', '7,000원', '1.2km']),
        ('온밥', ['비빔밥', '8,000원', '850m']),
      ]) {
        final card = readerElements(store);
        expect(card, findsOne, reason: store);
        final name = spokenName(card.evaluate().single);
        expect(name, startsWith(store));
        for (final detail in details) {
          expect(name, contains(detail), reason: store);
        }
        // Reading a card must not trigger an action.
        expect(card, isSemantics(hasTapAction: false), reason: store);
      }

      final summary = readerElementsNamed('3km 이내에서 두 곳을 찾았어요.');
      expect(summary, findsOne);
      expect(summary, isSemantics(hasTapAction: false));
      for (final action in ['지도에서 찾기', '복사']) {
        expect(readerElementsNamed(action), findsOne, reason: action);
        expect(
          readerElementsNamed(action),
          isSemantics(isButton: true, hasTapAction: true),
          reason: action,
        );
      }
      // The header is text, not part of a tap that closes the keyboard.
      expect(readerElementsNamed('얼마고 AI'), isSemantics(hasTapAction: false));
      semantics.dispose();
    });

    testWidgets('a lone copy chip does not take the answer with it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      // Without recommended stores only the copy chip is shown.
      await _openAiChat(tester, withAnswer: true, withStores: false);

      expect(readerElementsNamed('복사'), findsOne);
      expect(
        readerElementsNamed('3km 이내에서 두 곳을 찾았어요.'),
        isSemantics(hasTapAction: false),
      );
      semantics.dispose();
    });

    testWidgets('store detail actions are buttons a screen reader can press', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openStoreDetail(tester);

      for (final name in ['전화', '가격 제보', '방문 인증', '길찾기', '전체보기']) {
        expect(readerElementsNamed(name), findsOne, reason: name);
        expect(
          readerElementsNamed(name),
          isSemantics(isButton: true, hasTapAction: true),
          reason: name,
        );
      }
      expect(readerElements('🍲'), findsNothing);

      tester.semantics.tap(readerElementsNamed('길찾기'));
      await tester.pumpAndSettle();
      expect(find.text('길찾기 화면'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets("today's pick reads its tabs, cards and buttons", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openTodaysPick(tester);

      expect(readerElements('뒤로가기'), findsOne);
      expect(
        readerElementsNamed('날씨 기반'),
        isSemantics(isButton: true, hasTapAction: true, isSelected: true),
      );
      expect(readerElementsNamed('가까운 거리'), isSemantics(isSelected: false));
      expect(
        readerElements('다 시청 칼국수'),
        isSemantics(isButton: true, hasTapAction: true),
      );
      for (final action in ['지도에서 보기', '이 루트로 보기']) {
        expect(readerElements(action), findsOne, reason: action);
        expect(
          readerElementsNamed(action),
          isSemantics(isButton: true, hasTapAction: true),
          reason: action,
        );
      }

      tester.semantics.tap(readerElementsNamed('가까운 거리'));
      await tester.pumpAndSettle();
      expect(readerElementsNamed('가까운 거리'), isSemantics(isSelected: true));
      expect(readerElementsNamed('날씨 기반'), isSemantics(isSelected: false));
      semantics.dispose();
    });
  });
}

/// The distance slider in the radius sheet.
SemanticsFinder _radiusSlider() => find.semantics.byPredicate(
  (node) =>
      !node.isMergedIntoParent &&
      node.getSemanticsData().flagsCollection.isSlider,
  describeMatch: (_) => 'the distance slider',
);

Future<void> _openRadiusSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: Center(child: RecommendationRadiusButton())),
      ),
    ),
  );
  await tester.tap(find.byType(RecommendationRadiusButton));
  await tester.pumpAndSettle();
}

Future<void> _openFilterSheet(WidgetTester tester, SearchFilter current) async {
  _setViewport(tester, const Size(430, 1400));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<SearchFilter>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SearchFilterSheet(current: current),
              ),
              child: const Text('필터 열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('필터 열기'));
  await tester.pumpAndSettle();
}

Future<void> _openDirections(WidgetTester tester) async {
  _setViewport(tester, const Size(390, 1200));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DirectionsExternalAppScreen(
                    storeName: '미락칼국수',
                    address: '서울특별시 중구 세종대로 110',
                    latitude: 37.5663,
                    longitude: 126.9779,
                    startLatitude: 37.5665,
                    startLongitude: 126.978,
                  ),
                ),
              ),
              child: const Text('길찾기 열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('길찾기 열기'));
  await tester.pumpAndSettle();
}

Future<void> _openSearch(
  WidgetTester tester, {
  SearchFilter filter = const SearchFilter(),
}) async {
  _setViewport(tester, const Size(390, 900));
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                SearchResultScreen(initialQuery: '칼국수', initialFilter: filter),
          ),
          GoRoute(
            path: AppRoutes.storeDetail,
            builder: (_, _) => const Scaffold(body: Text('상세 화면')),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAiChat(
  WidgetTester tester, {
  bool withAnswer = false,
  bool withStores = true,
}) async {
  _setViewport(tester, const Size(390, 1600));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiChatHistoryProvider.overrideWith(
          (ref) => [
            if (withAnswer) ...[
              const AiChatMessage(text: '점심 추천', isBot: false),
              AiChatMessage(
                text:
                    '3km 이내에서 두 곳을 찾았어요.\n'
                    '1. 미락칼국수 — 칼국수 · 7,000원 · 1.2km\n'
                    '2. 온밥 — 비빔밥 · 8,000원 · 850m',
                isBot: true,
                recommendedStoreIds: withStores ? const ['near'] : const [],
                recommendedStores: withStores
                    ? [_store('near', '미락칼국수', '7,000', 37.5663, 126.9779)]
                    : const [],
              ),
            ],
          ],
        ),
      ],
      child: const MaterialApp(home: AiRecommendChatScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openStoreDetail(WidgetTester tester) async {
  _setViewport(tester, const Size(390, 844));
  final store = Store.fromJson({
    'storeName': '24시 옛날집',
    'address': '서울특별시 중구 세종대로 110',
    'industry': '한식',
    'phoneNumber': '02-123-4567',
    'menu1': '김치찌개',
    'price1': '9000',
    'latitude': 37.5665,
    'longitude': 126.978,
    'source': 'GOV',
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storeReviewProvider.overrideWith((ref) => _LocalReviews())],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => StoreDetailScreen(store: store),
            ),
            GoRoute(
              path: AppRoutes.directionsExternalApp,
              builder: (_, _) => const Scaffold(body: Text('길찾기 화면')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Today's pick with the server down, so it lists the nearest stores of the
/// catalog.
Future<void> _openTodaysPick(WidgetTester tester) async {
  _setViewport(tester, const Size(390, 1400));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todaysPickServiceProvider.overrideWithValue(_DownTodaysPickService()),
      ],
      child: const MaterialApp(home: TodaysPickScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _DownTodaysPickService extends TodaysPickService {
  @override
  Future<Map<String, dynamic>> getTodaysPick({
    double? lat,
    double? lng,
    int radiusMeters = 3000,
  }) async =>
      recommendationError(RecommendationFailure.server, statusCode: 500);

  @override
  Future<Map<String, dynamic>> getRoute({
    double? lat,
    double? lng,
    int radiusMeters = 3000,
  }) async => const {};
}

class _LocalReviews extends StoreReviewNotifier {
  @override
  Future<void> loadReviews(String storeId, {bool force = false}) async {}
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Store _store(
  String id,
  String name,
  String price,
  double latitude,
  double longitude,
) => Store.fromJson({
  'storeId': id,
  'storeName': name,
  'industry': '한식',
  'menu1': '칼국수',
  'price1': price,
  'latitude': latitude,
  'longitude': longitude,
  'source': 'GOV',
});

Position _position(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.now(),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
