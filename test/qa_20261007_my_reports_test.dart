import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/my_reports_v2_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_detail_v2_screen.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/screens/mypage_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 10/7 QA에서 본 시연 계정의 내 제보와 같은 모양의 응답입니다.
const _infoNoChange = {
  'id': 'info-no-change',
  'storeId': 'store-hak',
  'storeName': '동양미래대학교 학식당',
  'reportType': 'STORE_INFO',
  'changeType': 'other',
  'description': '메뉴 정보 확인 요청',
  'menu1': '한식',
  'price1': '6500',
  'status': 'APPROVED',
  'resolution': 'NO_CHANGE',
  'createdAt': '2026-10-07T02:44:00Z',
};
const _priceRejected = {
  'id': 'price-rejected',
  'storeId': 'store-jang',
  'storeName': '정장군숯불구이전문점',
  'changeType': 'rise',
  'menu1': '삼겹살(200g)',
  'price1': '16000',
  'status': 'REJECTED',
  'rejectReason': '메뉴판 사진으로 가격을 확인할 수 없어요.',
  'createdAt': '2026-09-23T03:00:00Z',
};
const _legacyApproved = {
  'id': 'legacy-approved',
  'storeName': '노랑통닭',
  'menu1': '후라이드',
  'price1': '17000',
  'status': 'APPROVED',
  'createdAt': '2026-09-01T03:00:00Z',
};
const _newStoreApproved = {
  'id': 'new-store-approved',
  'storeName': '새로 등록된 식당',
  'menu1': '김밥',
  'price1': '3000',
  'status': 'APPROVED',
  'resolution': 'NEW_STORE',
  'createdAt': '2026-08-30T03:00:00Z',
};
const _reports = [
  _infoNoChange,
  _priceRejected,
  _legacyApproved,
  _newStoreApproved,
];

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

/// 내 제보 목록은 [reports]로, 매장 조회는 [stores]로 답하고 조회한 매장을 기록합니다.
ReportService _service({
  List<Map<String, Object>> reports = _reports,
  Map<String, Map<String, Object>> stores = const {},
  List<String>? storeRequests,
}) {
  return ReportService(
    MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/report/my') return _json(reports);
      if (path.startsWith('/api/stores/')) {
        final id = Uri.decodeComponent(path.substring('/api/stores/'.length));
        storeRequests?.add(id);
        final store = stores[id];
        return store == null ? http.Response('', 404) : _json(store);
      }
      return http.Response('', 404);
    }),
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  Map<String, Object> json, {
  required ReportService service,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reportServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: ReportDetailV2Screen(
          initialReport: UserReportStatus.fromJson(json),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('qa-1007-session');
  });

  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets('a no-change review is filed apart from approvals and each card '
      'names its report kind (QA #13, #15)', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [reportServiceProvider.overrideWithValue(_service())],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MyReportsV2Screen()),
      ),
    );
    await tester.pumpAndSettle();

    // 전체 목록: 정보 오류 신고는 매장 대표 메뉴 대신 신고 유형으로 보입니다.
    expect(find.text('정보 오류 신고'), findsOneWidget);
    expect(find.text('신고 유형'), findsOneWidget);
    expect(find.text('기타'), findsOneWidget);
    expect(find.text('한식 6,500원'), findsNothing);
    expect(find.text('가격 변동 제보'), findsOneWidget);
    expect(find.text('가격 인상'), findsOneWidget);
    expect(find.text('삼겹살(200g) 16,000원'), findsOneWidget);
    expect(find.text('새 매장 제보'), findsNWidgets(2));

    await tester.tap(find.text('승인 완료').first);
    await tester.pumpAndSettle();
    expect(find.text('노랑통닭'), findsOneWidget);
    expect(find.text('새로 등록된 식당'), findsOneWidget);
    expect(find.text('동양미래대학교 학식당'), findsNothing);

    await tester.tap(find.text('수정 없음').first);
    await tester.pumpAndSettle();
    expect(find.text('동양미래대학교 학식당'), findsOneWidget);
    expect(find.text('노랑통닭'), findsNothing);
    expect(find.text('내용을 검토했지만 매장 정보는 바꾸지 않은 제보예요.'), findsOneWidget);
  });

  testWidgets('the no-change tab stays hidden when there is no such review', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        reportServiceProvider.overrideWithValue(
          _service(reports: const [_legacyApproved, _priceRejected]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MyReportsV2Screen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('수정 없음'), findsNothing);
    expect(find.text('노랑통닭'), findsOneWidget);
  });

  testWidgets('an old approval without processing details reads as finished '
      '(QA #17)', (tester) async {
    final container = ProviderContainer(
      overrides: [reportServiceProvider.overrideWithValue(_service())],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MyReportsV2Screen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('승인 완료').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('확인 필요'), findsNothing);

    await _pumpDetail(tester, _legacyApproved, service: _service());
    expect(find.text('검토를 마치고 승인된 제보예요.'), findsOneWidget);
    expect(find.textContaining('확인 필요'), findsNothing);
    expect(find.text('승인된 제보 · 수정 불가'), findsOneWidget);
  });

  testWidgets('a rejected price change shows its kind, the registered price '
      'and the reported price (QA #15)', (tester) async {
    final storeRequests = <String>[];
    await _pumpDetail(
      tester,
      _priceRejected,
      service: _service(
        storeRequests: storeRequests,
        stores: {
          'store-jang': {
            'storeId': 'store-jang',
            'storeName': '정장군숯불구이전문점',
            'address': '서울 서대문구',
            'industry': '한식',
            'menu1': '삼겹살(200g)',
            'price1': '15000',
            'source': 'GOV',
          },
        },
      ),
    );
    // 반려 사유 창을 닫고 상세 내용을 확인합니다.
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(storeRequests, ['store-jang']);
    expect(find.text('가격 변동 제보'), findsOneWidget);
    expect(find.text('변동 유형'), findsOneWidget);
    expect(find.text('가격 인상'), findsOneWidget);
    expect(find.text('기존 가격'), findsOneWidget);
    expect(find.text('15,000원'), findsOneWidget);
    expect(find.text('제보한 가격'), findsOneWidget);
    expect(find.text('16,000원'), findsOneWidget);
    expect(find.text('대표 메뉴'), findsNothing);
  });

  testWidgets('an approved price change does not present the applied price as '
      'the old one (QA #15)', (tester) async {
    final storeRequests = <String>[];
    await _pumpDetail(tester, {
      ..._priceRejected,
      'id': 'price-approved',
      'status': 'APPROVED',
      'resolution': 'PRICE',
      'rejectReason': '',
    }, service: _service(storeRequests: storeRequests));
    expect(storeRequests, isEmpty);
    expect(find.text('기존 가격'), findsNothing);
    expect(find.text('제보한 가격'), findsOneWidget);
    expect(find.text('승인된 제보 · 수정 불가'), findsOneWidget);
  });

  testWidgets('MY recent reports use the same kind summary and no-change '
      'badge (QA #13, #15)', (tester) async {
    await ApiClient.setSessionToken('active-token');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(
      () async {
        final router = GoRouter(
          initialLocation: '/mypage',
          routes: [
            GoRoute(path: '/mypage', builder: (_, _) => const MypageScreen()),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              reportServiceProvider.overrideWithValue(_service()),
              authStateProvider.overrideWith(
                (ref) => const AuthState(
                  isLoggedIn: true,
                  provider: '카카오',
                  email: 'saver@example.com',
                  sessionToken: 'active-token',
                ),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
      },
      () => MockClient(
        (request) async => http.Response(
          request.url.path == '/api/favorites' ? '[]' : '{}',
          200,
        ),
      ),
    );

    expect(find.text('정보 오류 신고 · 기타'), findsOneWidget);
    expect(find.text('수정 없음'), findsOneWidget);
    expect(find.text('가격 인상 · 삼겹살(200g) 16,000원'), findsOneWidget);
    expect(find.text('한식 6,500원'), findsNothing);
  });
}
