import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/screens/login_flow_screen.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/errors/presentation/screens/favorite_cancel_confirm_screen.dart';
import 'package:howmuch/features/errors/presentation/screens/store_info_report_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/store/presentation/screens/price_change_report_screen.dart';
import 'package:howmuch/features/store/presentation/screens/review_write_screen.dart';
import 'package:howmuch/features/store/presentation/screens/store_detail_screen.dart';
import 'package:howmuch/features/store/presentation/screens/visit_verification_screen.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kakao login that succeeds at once and, like the real service, marks the
/// app as logged in, which starts a new favorites list for the account.
class _FakeLoginService extends KakaoLoginService {
  _FakeLoginService(this._appRef) : super(_appRef);

  final Ref _appRef;

  @override
  Future<KakaoLoginResult> login({bool navigate = true}) async {
    await ApiClient.setSessionToken('store-gate-session');
    _appRef.read(authStateProvider.notifier).state = const AuthState(
      isLoggedIn: true,
      provider: '카카오',
      email: '',
      sessionToken: 'store-gate-session',
    );
    return const KakaoLoginResult(KakaoLoginStatus.success);
  }
}

/// Favorites on the server; like the server, it answers only an account.
/// With [listAnswer] the list arrives only once that completes.
class _FakeFavoriteApi extends FavoriteApiService {
  _FakeFavoriteApi({this.saved = const [], this.listAnswer});

  final List<String> saved;
  final Future<void>? listAnswer;
  final added = <String>[];
  final removed = <String>[];

  @override
  Future<List<FavoriteStoreModel>> fetchFavorites() async {
    if (!ApiClient.isAuthenticated) throw Exception('401');
    final answer = listAnswer;
    if (answer != null) await answer;
    return [
      for (final id in saved)
        FavoriteStoreModel.fromJson({'storeId': id, 'storeName': '매장 $id'}),
    ];
  }

  @override
  Future<FavoriteStoreModel> addFavorite({
    required String storeId,
    required String storeName,
  }) async {
    added.add(storeId);
    return FavoriteStoreModel.fromJson({
      'storeId': storeId,
      'storeName': storeName,
    });
  }

  @override
  Future<void> removeFavorite(String storeId) async => removed.add(storeId);
}

class _NoReviews extends StoreReviewNotifier {
  final submitted = <Review>[];

  @override
  Future<void> loadReviews(String storeId, {bool force = false}) async {
    state = {...state, storeId: const AsyncValue.data([])};
  }

  @override
  Future<bool> addReview(Review review) async {
    submitted.add(review);
    return true;
  }
}

final _store = Store.fromJson({
  'storeId': 'store-1',
  'storeName': '동네 식당',
  'address': '서울 구로구',
  'industry': '한식',
  'menu1': '국수',
  'price1': '5000',
  'latitude': 37.5,
  'longitude': 127.0,
});

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

/// Report service that accepts every report and records what was sent.
ReportService _reportService(List<Map<String, dynamic>> sent) => ReportService(
  MockClient((request) async {
    if (request.method == 'POST') {
      sent.add(jsonDecode(request.body) as Map<String, dynamic>);
      return _json({'success': true, 'reportId': 'report-1'});
    }
    return _json(<Object>[]);
  }),
);

/// Opens [location] on top of a plain screen, so finishing a form shows
/// '이전 화면' again.
Future<GoRouter> _open(
  WidgetTester tester,
  String location, {
  Object? extra,
  List<Override> overrides = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('이전 화면')),
      ),
      GoRoute(
        path: AppRoutes.storeDetail,
        builder: (_, state) => StoreDetailScreen(store: state.extra! as Store),
      ),
      GoRoute(
        path: AppRoutes.visitVerification,
        builder: (_, state) =>
            VisitVerificationScreen(store: state.extra as Store?),
      ),
      GoRoute(
        path: AppRoutes.storeInfoReport,
        builder: (_, state) =>
            StoreInfoReportScreen(store: state.extra as Store?),
      ),
      GoRoute(
        path: AppRoutes.priceChangeReport,
        builder: (_, state) =>
            PriceChangeReportScreen(store: state.extra as Store?),
      ),
      GoRoute(
        path: AppRoutes.reviewWrite,
        builder: (_, state) => ReviewWriteScreen(store: state.extra as Store?),
      ),
      GoRoute(
        path: AppRoutes.favoriteCancelConfirm,
        builder: (_, _) => const FavoriteCancelConfirmScreen(
          storeId: 'store-1',
          storeName: '동네 식당',
        ),
      ),
      GoRoute(
        path: AppRoutes.loginFlow,
        builder: (_, _) => const LoginFlowScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kakaoLoginServiceProvider.overrideWith(_FakeLoginService.new),
        currentStoreDetailProvider(
          _store.id,
        ).overrideWith((ref) async => _store),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push(location, extra: extra);
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The prompt explains [message]; the guest chooses later.
Future<void> _later(WidgetTester tester, String message) async {
  expect(find.text('로그인이 필요해요'), findsOneWidget);
  expect(find.text(message), findsOneWidget);
  await tester.tap(find.text('나중에'));
  await tester.pumpAndSettle();
  expect(ApiClient.isAuthenticated, isFalse);
}

/// The prompt explains [message]; the guest logs in with Kakao.
Future<void> _logIn(WidgetTester tester, String message) async {
  expect(find.text('로그인이 필요해요'), findsOneWidget);
  expect(find.text(message), findsOneWidget);
  await tester.tap(find.byKey(const Key('login_required_confirm')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('카카오로 계속하기'));
  await tester.pumpAndSettle();
  expect(ApiClient.isAuthenticated, isTrue);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      authTermsAcceptedPreferenceKey: true,
    });
    await ApiClient.setSessionToken(null);
  });
  tearDown(() => ApiClient.setSessionToken(null));

  group('store detail', () {
    const favoriteMessage = '찜한 매장은 로그인하면 저장돼요.';

    List<Override> storeOverrides(_FakeFavoriteApi favorites) => [
      favoriteApiServiceProvider.overrideWithValue(favorites),
      storeReviewProvider.overrideWith((ref) => _NoReviews()),
    ];

    testWidgets('a guest saving a store logs in and comes back with it saved', (
      tester,
    ) async {
      final favorites = _FakeFavoriteApi();
      await _open(
        tester,
        AppRoutes.storeDetail,
        extra: _store,
        overrides: storeOverrides(favorites),
      );

      await _tapAndSettle(tester, find.byTooltip('찜하기'));
      await _later(tester, favoriteMessage);
      expect(favorites.added, isEmpty);
      expect(find.byTooltip('찜하기'), findsOneWidget);

      await _tapAndSettle(tester, find.byTooltip('찜하기'));
      await _logIn(tester, favoriteMessage);
      expect(find.byType(StoreDetailScreen), findsOneWidget);
      expect(favorites.added, ['store-1']);
      expect(find.byTooltip('찜 해제'), findsOneWidget);
    });

    testWidgets('a store the account already saved stays saved after login', (
      tester,
    ) async {
      final favorites = _FakeFavoriteApi(saved: ['store-1']);
      await _open(
        tester,
        AppRoutes.storeDetail,
        extra: _store,
        overrides: storeOverrides(favorites),
      );

      await _tapAndSettle(tester, find.byTooltip('찜하기'));
      await _logIn(tester, favoriteMessage);
      expect(favorites.added, isEmpty);
      expect(favorites.removed, isEmpty, reason: 'the guest asked to save it');
      expect(find.byTooltip('찜 해제'), findsOneWidget);
    });

    testWidgets('visit verification asks a guest before it opens', (
      tester,
    ) async {
      const message = '로그인하면 방문을 인증하고 아낀 금액을 절약 리포트에 모을 수 있어요.';
      await _open(
        tester,
        AppRoutes.storeDetail,
        extra: _store,
        overrides: storeOverrides(_FakeFavoriteApi()),
      );

      await _tapAndSettle(tester, find.text('방문 인증'));
      await _later(tester, message);
      expect(find.byType(VisitVerificationScreen), findsNothing);

      await _tapAndSettle(tester, find.text('방문 인증'));
      await _logIn(tester, message);
      expect(find.byType(VisitVerificationScreen), findsOneWidget);
    });

    testWidgets('a report sent after login returns to the store showing the '
        "account's favorites", (tester) async {
      const message = '로그인하면 작성한 신고가 바로 접수돼요.';
      final sent = <Map<String, dynamic>>[];
      await _open(
        tester,
        AppRoutes.storeDetail,
        extra: _store,
        overrides: [
          ...storeOverrides(_FakeFavoriteApi(saved: ['store-1'])),
          reportServiceProvider.overrideWithValue(_reportService(sent)),
        ],
      );
      expect(find.byTooltip('찜하기'), findsOneWidget);

      await _tapAndSettle(tester, find.byTooltip('매장 정보 오류 신고'));
      await tester.enterText(find.byType(TextField).first, '6000');
      await tester.enterText(find.byType(TextField).last, '국수 가격이 올랐어요');
      await _tapAndSettle(tester, find.text('신고 접수하기'));
      await _later(tester, message);
      expect(sent, isEmpty);
      expect(find.text('국수 가격이 올랐어요'), findsOneWidget);

      await _tapAndSettle(tester, find.text('신고 접수하기'));
      await _logIn(tester, message);
      expect(sent.single['price1'], '6000');
      expect(sent.single['description'], '국수 가격이 올랐어요');
      expect(find.byType(StoreDetailScreen), findsOneWidget);
      expect(find.byTooltip('찜 해제'), findsOneWidget);
    });
  });

  testWidgets('a guest review asks to log in once complete and is sent after '
      'login', (tester) async {
    const message = '로그인하면 작성한 리뷰가 바로 등록돼요.';
    final reviews = _NoReviews();
    await _open(
      tester,
      AppRoutes.reviewWrite,
      extra: _store,
      overrides: [storeReviewProvider.overrideWith((ref) => reviews)],
    );

    await _tapAndSettle(tester, find.text('리뷰 등록하기'));
    expect(find.text('로그인이 필요해요'), findsNothing);
    expect(find.text('별점을 선택해주세요.'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '김치찌개');
    await tester.enterText(fields.at(1), '8,000');
    await tester.enterText(fields.at(2), '가격이 합리적이에요.');
    await _tapAndSettle(tester, find.byIcon(Icons.star_rounded).last);
    await _tapAndSettle(tester, find.text('최근 1개월 이내 방문했어요'));
    await _tapAndSettle(tester, find.text('가격 정보를 직접 확인했어요'));

    await _tapAndSettle(tester, find.text('리뷰 등록하기'));
    await _later(tester, message);
    expect(reviews.submitted, isEmpty);
    expect(find.text('가격이 합리적이에요.'), findsOneWidget);

    await _tapAndSettle(tester, find.text('리뷰 등록하기'));
    await _logIn(tester, message);
    final review = reviews.submitted.single;
    expect(review.storeId, 'store-1');
    expect(review.menu, '김치찌개');
    expect(review.price, 8000);
    expect(review.content, '가격이 합리적이에요.');
    expect(review.stars, 5);
    expect(find.text('이전 화면'), findsOneWidget);
  });

  testWidgets('a guest price change report is sent right after login', (
    tester,
  ) async {
    const message = '로그인하면 작성한 제보가 바로 접수돼요.';
    final sent = <Map<String, dynamic>>[];
    await _open(
      tester,
      AppRoutes.priceChangeReport,
      extra: _store,
      overrides: [
        reportServiceProvider.overrideWithValue(_reportService(sent)),
      ],
    );

    await tester.enterText(find.byType(TextField).at(1), '6000');
    await _tapAndSettle(
      tester,
      find.descendant(
        of: find.ancestor(
          of: find.text('직접 메뉴판 가격을 확인했어요'),
          matching: find.byType(Row),
        ),
        matching: find.byType(Checkbox),
      ),
    );
    await _tapAndSettle(tester, find.text('가격 변동 제보하기'));
    await _later(tester, message);
    expect(sent, isEmpty);

    await _tapAndSettle(tester, find.text('가격 변동 제보하기'));
    await _logIn(tester, message);
    expect(sent.single['menu1'], '국수');
    expect(sent.single['price1'], '6000');
    expect(sent.single['changeType'], 'rise');
    expect(find.text('이전 화면'), findsOneWidget);
  });

  testWidgets('unfavoriting as a guest logs in and then removes the store', (
    tester,
  ) async {
    const message = '로그인하면 이 매장의 찜을 바로 해제해요.';
    final listAnswered = Completer<void>();
    final favorites = _FakeFavoriteApi(
      saved: ['store-1', 'store-2', 'store-3'],
      listAnswer: listAnswered.future,
    );
    await _open(
      tester,
      AppRoutes.favoriteCancelConfirm,
      overrides: [favoriteApiServiceProvider.overrideWithValue(favorites)],
    );
    final remove = find.widgetWithText(FilledButton, '찜 해제');

    await _tapAndSettle(tester, remove);
    await _later(tester, message);
    expect(favorites.removed, isEmpty);
    expect(find.text('찜을 해제할까요?'), findsOneWidget);

    await _tapAndSettle(tester, remove);
    await _logIn(tester, message);
    // The account's list arrives some frames later, as over a network.
    expect(find.text('해제 중...'), findsOneWidget);
    // Once the removal runs, '유지하기' can no longer keep the store.
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '유지하기'))
          .onPressed,
      isNull,
    );
    listAnswered.complete();
    await tester.pumpAndSettle();
    expect(favorites.removed, ['store-1']);
    expect(find.text('이전 화면'), findsOneWidget);
    // The account's favorites are read before the store is removed, so the
    // count keeps the other two instead of dropping to 0.
    final container = ProviderScope.containerOf(
      tester.element(find.text('이전 화면')),
    );
    expect(container.read(userProfileProvider).favoriteStoreCount, 2);
  });
}
