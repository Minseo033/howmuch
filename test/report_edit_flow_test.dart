import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/community/presentation/screens/report_complete_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_create_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_detail_v2_screen.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/community/presentation/state/user_report_model.dart';
import 'package:howmuch/features/errors/presentation/screens/store_info_report_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/store/presentation/screens/price_change_report_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: _jsonHeaders);

Map<String, dynamic> _priceReportJson({String price = '6500'}) => {
  'id': 'price-1',
  'storeId': 'store-1',
  'storeName': '어머니 손맛 식당',
  'industry': '한식',
  'address': '서울특별시 서초구 서초대로 50',
  'menu1': '순두부찌개',
  'price1': price,
  'changeType': 'rise',
  'description': '메뉴판이 바뀌었어요',
  'checkedMenuPrice': true,
  'imageUrls': ['https://example.com/menu.jpg'],
  'status': 'PENDING',
  'createdAt': '2026-10-05T09:00:00Z',
};

const _storeJson = {
  'storeId': 'store-1',
  'storeName': '어머니 손맛 식당',
  'address': '서울특별시 서초구 서초대로 50',
  'industry': '한식',
  'menu1': '순두부찌개',
  'price1': '6000',
  'menu2': '제육볶음',
  'price2': '8000',
  'latitude': 37.49,
  'longitude': 127.01,
  'source': 'GOV',
};

void _useTallView(WidgetTester tester, {double height = 1400}) {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('report-flow-session');
  });

  tearDown(() => ApiClient.setSessionToken(null));

  group('price change report edit (P1-6)', () {
    late List<http.Request> requests;
    late Map<String, dynamic> saved;
    late ReportService service;

    setUp(() {
      requests = [];
      saved = _priceReportJson();
      service = ReportService(
        MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (request.method == 'GET' && path == '/api/stores/store-1') {
            return _json(_storeJson);
          }
          if (request.method == 'PUT') {
            saved = {...saved, ...jsonDecode(request.body) as Map};
            return _json({'success': true, 'reportId': 'price-1'});
          }
          if (request.method == 'GET' && path == '/api/report/my') {
            return _json([saved]);
          }
          return _json({'success': false}, 404);
        }),
      );
    });

    Future<ProviderContainer> openEditor(WidgetTester tester) async {
      _useTallView(tester);
      final report = UserReportStatus.fromJson(_priceReportJson());
      final container = ProviderContainer(
        overrides: [reportServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      container.read(userReportsProvider.notifier).setReports([report]);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('제보 상세 자리')),
          ),
          GoRoute(
            path: '/edit',
            builder: (_, state) => PriceChangeReportScreen(
              initialReport: state.extra! as UserReportStatus,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.push('/edit', extra: report);
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('saves with the same id, store and change type', (
      tester,
    ) async {
      final container = await openEditor(tester);

      expect(find.text('가격 변동 제보 수정'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('price-report-locked-notice')),
        findsOneWidget,
      );
      expect(find.text('기존 가격 6,000원'), findsOneWidget);
      final menuField = tester.widget<TextField>(find.byType(TextField).at(0));
      expect(menuField.controller!.text, '순두부찌개');
      expect(menuField.readOnly, isTrue);

      // 변동 유형은 바꿀 수 없어 입력해 둔 가격도 그대로 남습니다.
      await tester.tap(find.text('↘  가격 인하'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        '6500',
      );

      await tester.enterText(find.byType(TextField).at(1), '7000');
      await tester.tap(find.text('제보 수정하기'));
      await tester.pumpAndSettle();

      final put = requests.singleWhere((request) => request.method == 'PUT');
      expect(put.url.path, '/api/report/store/price-1');
      final body = jsonDecode(put.body) as Map<String, dynamic>;
      expect(body['storeId'], 'store-1');
      expect(body['storeName'], '어머니 손맛 식당');
      expect(body['changeType'], 'rise');
      expect(body['menu1'], '순두부찌개');
      expect(body['price1'], '7000');
      expect(body['checkedMenuPrice'], isTrue);
      expect(body['description'], '메뉴판이 바뀌었어요');
      expect(body['imageUrls'], ['https://example.com/menu.jpg']);
      expect(body.containsKey('reportType'), isFalse);
      expect(requests.where((request) => request.method == 'POST'), isEmpty);
      expect(find.text('제보 상세 자리'), findsOneWidget);
      expect(
        container.read(userReportsProvider).single.menuPrices.single.price,
        '7000',
      );
    });

    testWidgets(
      'explains delete and re-report when the price contradicts the locked type',
      (tester) async {
        await openEditor(tester);

        await tester.enterText(find.byType(TextField).at(1), '5000');
        await tester.tap(find.text('제보 수정하기'));
        await tester.pump();

        expect(
          find.text('기존 가격보다 낮아요. 변동 유형을 바꾸려면 제보를 삭제하고 다시 제보해주세요.'),
          findsOneWidget,
        );
        expect(requests.where((request) => request.method == 'PUT'), isEmpty);
      },
    );

    testWidgets('the application router opens the price change editor', (
      tester,
    ) async {
      _useTallView(tester);
      final container = ProviderContainer(
        overrides: [reportServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);
      router.go(AppRoutes.myReportsV2);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.push(
        AppRoutes.priceChangeReport,
        extra: UserReportStatus.fromJson(_priceReportJson()),
      );
      await tester.pumpAndSettle();
      expect(find.text('가격 변동 제보 수정'), findsOneWidget);
      expect(find.text('어머니 손맛 식당'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), '7500');
      await tester.tap(find.text('제보 수정하기'));
      await tester.pumpAndSettle();

      final put = requests.singleWhere((request) => request.method == 'PUT');
      final body = jsonDecode(put.body) as Map<String, dynamic>;
      expect(put.url.path, '/api/report/store/price-1');
      expect(body['storeId'], 'store-1');
      expect(body['changeType'], 'rise');
      expect(body['price1'], '7500');
      expect(find.text('가격 변동 제보 수정'), findsNothing);
    });
  });

  testWidgets('edit buttons open the editor that matches the report type', (
    tester,
  ) async {
    final cases = <Map<String, dynamic>, String>{
      _priceReportJson(): '가격 변동 수정 화면',
      {
        'id': 'new-store',
        'storeName': '새 식당',
        'menu1': '국수',
        'price1': '5000',
        'status': 'PENDING',
      }: '신규 매장 작성 화면',
      {
        'id': 'info-1',
        'storeId': 'store-1',
        'storeName': '어머니 손맛 식당',
        'reportType': 'STORE_INFO',
        'changeType': 'closed',
        'description': '문을 닫았어요',
        'status': 'PENDING',
      }: '정보 신고 화면',
    };
    for (final MapEntry(key: json, value: expectedScreen) in cases.entries) {
      final report = UserReportStatus.fromJson(json);
      final container = ProviderContainer(
        overrides: [
          reportServiceProvider.overrideWithValue(
            ReportService(MockClient((_) async => _json([json]))),
          ),
        ],
      );
      final router = GoRouter(
        initialLocation: '/detail',
        routes: [
          GoRoute(
            path: '/detail',
            builder: (_, _) => ReportDetailV2Screen(initialReport: report),
          ),
          GoRoute(
            path: AppRoutes.priceChangeReport,
            builder: (_, state) => Text(
              state.extra is UserReportStatus ? '가격 변동 수정 화면' : '잘못된 전달',
            ),
          ),
          GoRoute(
            path: AppRoutes.reportCreate,
            builder: (_, state) => Text(
              state.extra is UserReportStatus ? '신규 매장 작성 화면' : '잘못된 전달',
            ),
          ),
          GoRoute(
            path: AppRoutes.storeInfoReport,
            builder: (_, state) => Text(
              state.extra is StoreInfoReportTarget ? '정보 신고 화면' : '잘못된 전달',
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('제보 수정하기'));
      await tester.pumpAndSettle();
      expect(
        find.text(expectedScreen),
        findsOneWidget,
        reason: '${json['id']}',
      );
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
    }
  });

  testWidgets('general form refuses to save a price change report', (
    tester,
  ) async {
    _useTallView(tester, height: 1600);
    var requests = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (_) =>
                const AuthState(isLoggedIn: true, provider: '카카오', email: ''),
          ),
          reportServiceProvider.overrideWithValue(
            ReportService(
              MockClient((_) async {
                requests++;
                return _json({});
              }),
            ),
          ),
        ],
        child: MaterialApp(
          home: ReportCreateScreen(
            initialReport: UserReportStatus.fromJson(_priceReportJson()),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('제보 수정하기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('제보 수정하기'));
    await tester.pump();

    expect(find.text('가격 변동 제보와 정보 신고는 제보 상세의 수정하기에서 고쳐주세요.'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets(
    'completion replaces the form so back never reopens the filled form (P1-7)',
    (tester) async {
      _useTallView(tester, height: 1600);
      final requests = <http.Request>[];
      final service = ReportService(
        MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST' &&
              request.url.path == '/api/report/store') {
            return _json({'success': true, 'reportId': 'new-1'});
          }
          if (request.url.path == '/api/report/my') {
            return _json([
              {
                'id': 'new-1',
                'storeName': '새 식당',
                'address': '서울 구로구 중앙로 1',
                'industry': '음식점 · 한식',
                'menu1': '국수',
                'price1': '5000',
                'status': 'PENDING',
                'createdAt': '2026-10-06T01:00:00Z',
              },
            ]);
          }
          return _json({}, 404);
        }),
      );
      final container = ProviderContainer(
        overrides: [
          reportServiceProvider.overrideWithValue(service),
          authStateProvider.overrideWith(
            (_) =>
                const AuthState(isLoggedIn: true, provider: '카카오', email: ''),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('커뮤니티 자리')),
          ),
          GoRoute(
            path: AppRoutes.reportCreate,
            builder: (_, _) => ReportCreateScreen(
              locationLookup: () async => null,
              placeSearch: (_, _, _) async => const [
                ReportPlaceSuggestion(
                  name: '새 식당',
                  address: '서울 구로구 중앙로 1',
                  category: '음식점 > 한식',
                ),
              ],
            ),
          ),
          GoRoute(
            path: AppRoutes.reportComplete,
            builder: (_, state) =>
                ReportCompleteScreen(reportId: state.uri.queryParameters['id']),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.push(AppRoutes.reportCreate);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('매장 검색'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('report-address-search-input')),
        '새 식당',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(ListTile), matching: find.text('새 식당')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(3), '국수');
      await tester.enterText(find.byType(TextField).at(4), '5000');
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('제보 제출하기'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('제보 제출하기'));
      await tester.pumpAndSettle();

      expect(find.text('제보가 접수되었어요'), findsOneWidget);
      expect(find.byType(ReportCreateScreen), findsNothing);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('커뮤니티 자리'), findsOneWidget);
      expect(find.byType(ReportCreateScreen), findsNothing);
      expect(
        requests.where(
          (request) =>
              request.method == 'POST' &&
              request.url.path == '/api/report/store',
        ),
        hasLength(1),
      );
      // 제보자는 서버가 로그인 세션으로 정하므로 계정 이메일을 보내지 않습니다(FE-COMM-33).
      final post = requests.firstWhere(
        (request) =>
            request.method == 'POST' && request.url.path == '/api/report/store',
      );
      expect((jsonDecode(post.body) as Map)['reporterId'], '');
    },
  );

  group('report save helpers', () {
    UserReportStatus status(Map<String, dynamic> json) =>
        UserReportStatus.fromJson(json);

    test('my reports are ordered newest first (FE-COMM-6)', () {
      final sorted = sortReportsNewestFirst([
        status({'id': 'old', 'createdAt': '2026-09-01T00:00:00Z'}),
        status({'id': 'unknown', 'createdAt': ''}),
        status({'id': 'new', 'createdAt': '2026-10-05T00:00:00Z'}),
        status({'id': 'mid', 'createdAt': '2026-09-20T00:00:00+09:00'}),
      ]);
      expect(sorted.map((item) => item.id), ['new', 'mid', 'old', 'unknown']);
    });

    test('fetchMyReports sorts the server list', () async {
      final service = ReportService(
        MockClient(
          (_) async => _json([
            {'id': 'a', 'createdAt': '2026-09-01T00:00:00Z'},
            {'id': 'b', 'createdAt': '2026-10-01T00:00:00Z'},
          ]),
        ),
      );
      final reports = await service.fetchMyReports();
      expect(reports!.map((item) => item.id), ['b', 'a']);
    });

    test('timed out saves are recognised from my reports (FE-COMM-7)', () {
      final sentWithPhoto = UserReport(
        storeId: 'store-1',
        storeName: '어머니 손맛 식당',
        industry: '한식',
        address: '서울',
        menu1: '순두부찌개',
        price1: '7000',
        changeType: 'rise',
        imageUrls: const ['https://cdn.example/new-upload.jpg'],
        reporterId: '',
        visitedRecently: false,
        checkedMenuPrice: true,
        latitude: 0,
        longitude: 0,
      );
      final saved = status({
        'id': 'server-id',
        'storeName': '어머니 손맛 식당',
        'menu1': '순두부찌개',
        'price1': '7000',
        'changeType': 'rise',
        'imageUrls': ['https://cdn.example/new-upload.jpg'],
        'status': 'PENDING',
      });
      final unrelated = status({
        'id': 'other',
        'storeName': '다른 식당',
        'menu1': '국수',
        'price1': '5000',
        'status': 'PENDING',
      });
      expect(
        matchSavedReport([unrelated, saved], sentWithPhoto)?.id,
        'server-id',
      );
      expect(matchSavedReport([unrelated], sentWithPhoto), isNull);

      // 수정은 같은 ID의 제보가 보낸 값과 같아야 반영된 것으로 봅니다.
      final stale = status({..._priceReportJson(), 'imageUrls': <String>[]});
      final applied = status({
        ..._priceReportJson(price: '7000'),
        'imageUrls': ['https://cdn.example/new-upload.jpg'],
      });
      expect(
        matchSavedReport([stale], sentWithPhoto, reportId: 'price-1'),
        isNull,
      );
      expect(
        matchSavedReport([applied], sentWithPhoto, reportId: 'price-1')?.id,
        'price-1',
      );
    });

    test(
      'photos uploaded before an unclear save are reused, not deleted',
      () async {
        final requests = <String>[];
        var uploads = 0;
        final service = ReportService(
          MockClient((request) async {
            requests.add(request.url.path);
            if (request.url.path == '/api/report/images') {
              uploads++;
              return _json({
                'imageUrls': ['https://cdn.example/upload-$uploads.jpg'],
              });
            }
            return _json({'success': true});
          }),
        );
        final session = ReportUploadSession();
        final photo = XFile.fromData(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00]),
          name: 'menu.jpg',
          path: '/tmp/howmuch-test-menu.jpg',
        );

        final first = await session.resolveImageUrls(service, [
          photo,
        ], uploadEnabled: true);
        session.saveOutcomeUnknown = true;
        await session.discardUnsaved(service);
        final retry = await session.resolveImageUrls(service, [
          photo,
        ], uploadEnabled: true);

        expect(first, ['https://cdn.example/upload-1.jpg']);
        expect(retry, first);
        expect(uploads, 1);
        expect(requests, isNot(contains('/api/report/images/cleanup')));

        session.saveOutcomeUnknown = false;
        await session.discardUnsaved(service);
        expect(requests, contains('/api/report/images/cleanup'));
      },
    );
  });
}
