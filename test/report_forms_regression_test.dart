import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/community/presentation/screens/report_create_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_detail_v2_screen.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/errors/presentation/screens/favorite_cancel_confirm_screen.dart';
import 'package:howmuch/features/errors/presentation/screens/store_info_report_screen.dart';
import 'package:howmuch/features/store/presentation/screens/price_change_report_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

void _useTallView(WidgetTester tester, {double height = 1400}) {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final _loggedIn = authStateProvider.overrideWith(
  (_) => const AuthState(isLoggedIn: true, provider: '카카오', email: ''),
);

class _CountingPhoto extends XFile {
  _CountingPhoto(super.bytes)
    : super.fromData(name: 'menu.png', path: '/tmp/howmuch-draft.png');

  int reads = 0;

  @override
  Future<Uint8List> readAsBytes() {
    reads++;
    return super.readAsBytes();
  }
}

GoRouter _routerWith(Widget screen, {String path = '/form'}) => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('이전 화면')),
    ),
    GoRoute(path: path, builder: (_, _) => screen),
    GoRoute(
      path: AppRoutes.login,
      builder: (_, _) => const Scaffold(body: Text('로그인 화면')),
    ),
  ],
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('forms-session');
    ReportDraftStash.discard();
  });

  tearDown(() async {
    await ApiClient.setSessionToken(null);
    ReportDraftStash.discard();
  });

  testWidgets('price mismatch report targets the chosen menu (FE-COMM-9)', (
    tester,
  ) async {
    _useTallView(tester);
    http.Request? saved;
    final service = ReportService(
      MockClient((request) async {
        if (request.method == 'POST') {
          saved = request;
          return _json({'success': true, 'reportId': 'info-new'});
        }
        return _json(<Object>[]);
      }),
    );
    final store = Store.fromJson({
      'storeId': 'store-1',
      'storeName': '동네 식당',
      'address': '서울 구로구',
      'menu1': '국수',
      'price1': '5000',
      'menu2': '김밥',
      'price2': '3000',
      'menu3': '라면',
      'price3': '4000',
      'latitude': 37.5,
      'longitude': 127.0,
    });
    final router = _routerWith(StoreInfoReportScreen(store: store));
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reportServiceProvider.overrideWithValue(service)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/form');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('info-report-menu-2')));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '3500');
    await tester.enterText(find.byType(TextField).last, '김밥 가격이 올랐어요');
    await tester.tap(find.text('신고 접수하기'));
    await tester.pumpAndSettle();

    final body = jsonDecode(saved!.body) as Map<String, dynamic>;
    expect(body['menu1'], '김밥');
    expect(body['price1'], '3500');
    expect(body['menu2'], '');
    expect(body['changeType'], 'price_mismatch');
    expect(body['reportType'], 'STORE_INFO');
    expect(find.text('이전 화면'), findsOneWidget);
  });

  testWidgets('multi-price menus cannot be reported as a rise (FE-COMM-10)', (
    tester,
  ) async {
    _useTallView(tester);
    var requests = 0;
    final store = Store.fromJson({
      'storeId': 'store-2',
      'storeName': '정식집',
      'address': '서울',
      'menu1': '국수',
      'price1': '5000',
      'menu2': '정식',
      'price2': '8,000~9,000',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportServiceProvider.overrideWithValue(
            ReportService(
              MockClient((_) async {
                requests++;
                return _json({});
              }),
            ),
          ),
        ],
        child: MaterialApp(home: PriceChangeReportScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    // 유형 칸마다 별도 화면 틀을 만들지 않습니다(FE-COMM-33 중첩 Scaffold 정리).
    expect(find.byType(Scaffold), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('price-report-menu-chip-정식')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('price-report-multi-price-notice')),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).at(1), '9500');
    await tester.tap(find.text('가격 변동 제보하기'));
    await tester.pump();

    expect(find.text(priceChangeMultiPriceMessage), findsWidgets);
    expect(requests, 0);
    expect(
      validatePriceChange(
        changeType: 'rise',
        menu: '정식',
        price: '9500',
        registeredMenus: const [(menu: '정식', price: '8,000~9,000')],
      ),
      priceChangeMultiPriceMessage,
    );
    expect(
      validatePriceChange(
        changeType: 'delete',
        menu: '정식',
        price: '',
        registeredMenus: const [(menu: '정식', price: '8,000~9,000')],
      ),
      isNull,
    );
  });

  testWidgets('a draft restored after login reads each photo once while typing '
      '(FE-COMM-14, FE-COMM-11)', (tester) async {
    _useTallView(tester, height: 1600);
    final photo = _CountingPhoto(base64Decode(_onePixelPng));
    ReportDraftStash.save(
      ReportDraft(
        store: '로그인 전 식당',
        category: '음식점 · 한식',
        address: '서울 구로구 중앙로 1',
        menus: const [(menu: '국수', price: '5000', free: false)],
        photos: [photo],
        visitedRecently: true,
        checkedMenuPrice: false,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_loggedIn],
        child: const MaterialApp(home: ReportCreateScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('로그인 전 식당'), findsOneWidget);
    expect(find.text('로그인 전에 작성하던 제보를 불러왔어요.'), findsOneWidget);
    expect(photo.reads, 1);

    for (final value in ['로그인 전', '로그인 전 식당 본점', '로그인 전 식당']) {
      await tester.enterText(find.byType(TextField).first, value);
      await tester.pump();
    }
    expect(photo.reads, 1);
  });

  testWidgets(
    'guests are told to log in first and keep their draft (FE-COMM-14)',
    (tester) async {
      _useTallView(tester, height: 1600);
      final router = _routerWith(const ReportCreateScreen());
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      router.push('/form');
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '게스트 식당');
      await tester.tap(find.byKey(const ValueKey('report-guest-login-tip')));
      await tester.pumpAndSettle();

      expect(find.text('로그인 화면'), findsOneWidget);
      expect(ReportDraftStash.take()?.store, '게스트 식당');
    },
  );

  testWidgets('leaving a filled form asks first (FE-COMM-31)', (tester) async {
    _useTallView(tester, height: 1600);
    final router = _routerWith(const ReportCreateScreen());
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [_loggedIn],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/form');
    await tester.pumpAndSettle();

    // 아무것도 입력하지 않았으면 바로 닫힙니다.
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.text('이전 화면'), findsOneWidget);

    router.push('/form');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '작성 중 식당');
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.text('작성을 그만두고 나갈까요?'), findsOneWidget);
    await tester.tap(find.text('계속 작성'));
    await tester.pumpAndSettle();
    expect(find.text('작성 중 식당'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('작성을 그만두고 나갈까요?'), findsOneWidget);
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('이전 화면'), findsOneWidget);
    expect(find.byType(ReportCreateScreen), findsNothing);
  });

  test('industry comes from the Kakao category before the store name '
      '(FE-COMM-19)', () {
    expect(
      normalizeReportIndustry('음식점 > 분식 > 김밥', placeName: '김밥천국 고속버스터미널점'),
      '음식점 · 분식',
    );
    expect(normalizeReportIndustry('음식점', placeName: '동네치킨'), '음식점 · 치킨');
    expect(
      normalizeReportIndustry('음식점', placeName: '터미널버스정류장 식당'),
      '음식점 · 기타',
    );
    expect(normalizeReportIndustry('', placeName: '터미널 주차장'), '교통·주차 · 주차장');
  });

  testWidgets(
    'a missing report keeps a header and offers a retry (FE-COMM-25)',
    (tester) async {
      var fail = true;
      final service = ReportService(
        MockClient(
          (_) async => fail ? _json({'message': '오류'}, 500) : _json(<Object>[]),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reportServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(
            home: ReportDetailV2Screen(reportId: 'gone'),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('제보 상세'), findsOneWidget);
      expect(find.byTooltip('뒤로가기'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('제보 정보를 불러오지 못했어요.'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('제보 정보를 찾을 수 없어요.'), findsOneWidget);
    },
  );

  test('photos over 5MB or beyond the limit are left out with a reason '
      '(FE-COMM-30)', () async {
    final small = XFile.fromData(Uint8List(10), name: 'small.jpg');
    final big = XFile.fromData(
      Uint8List(ReportService.maxImageBytes + 1),
      name: 'big.jpg',
    );
    final selection = await selectReportPhotos([
      small,
      big,
      small,
      small,
    ], remaining: 2);
    expect(selection.accepted, hasLength(2));
    expect(selection.oversized, 1);
    expect(selection.overLimit, 1);
    expect(
      reportPhotoSelectionNotice(oversized: 1, overLimit: 1),
      '5MB를 넘는 사진 1장은 첨부하지 않았어요. 사진은 최대 3장까지라 1장은 제외했어요.',
    );
    expect(reportPhotoSelectionNotice(oversized: 0, overLimit: 0), isNull);
  });

  testWidgets('favorite cancel explains a missing store and asks guests to '
      'log in (FE-COMM-32)', (tester) async {
    await ApiClient.setSessionToken(null);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FavoriteCancelConfirmScreen(storeId: '', storeName: '찜한 매장'),
        ),
      ),
    );
    expect(find.text('찜한 매장 정보를 찾을 수 없어요'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '찜 취소'))
          .onPressed,
      isNull,
    );
    // 다이얼로그를 감싸던 중첩 Scaffold 없이 화면 틀 하나만 씁니다.
    expect(find.byType(Scaffold), findsOneWidget);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FavoriteCancelConfirmScreen(
            storeId: 'store-1',
            storeName: '동네 식당',
          ),
        ),
      ),
    );
    await tester.tap(find.text('찜 취소'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_required_dialog')), findsOneWidget);
  });
}
