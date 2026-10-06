import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/my_reports_v2_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_complete_screen.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _longMenu = '아주 긴 이름의 특제 수제 돈까스 정식과 우동 세트 메뉴';
const _longAddress = '서울특별시 구로구 경인로 아주 긴 도로명 주소 123번길 45-6 지하 1층 101호';

final _reports = [
  {
    'id': 'pending-1',
    'storeName': '검토 식당',
    'address': _longAddress,
    'menu1': _longMenu,
    'price1': '12000',
    'description': '가격표 오류',
    'status': 'PENDING',
    'createdAt': '2026-10-05T00:00:00Z',
  },
  {
    'id': 'approved-1',
    'storeName': '승인 식당',
    'address': '서울 구로구',
    'menu1': '국수',
    'price1': '5000',
    'description': '위치 오류',
    'status': 'APPROVED',
    'resolution': 'NEW_STORE',
    'createdAt': '2026-10-01T00:00:00Z',
  },
];

Future<ProviderContainer> _pumpMyReports(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(320, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final service = ReportService(
    MockClient(
      (_) async => http.Response(
        jsonEncode(_reports),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      ),
    ),
  );
  final container = ProviderContainer(
    overrides: [reportServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  container
      .read(userReportsProvider.notifier)
      .setReports(_reports.map(UserReportStatus.fromJson).toList());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MyReportsV2Screen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('my-reports-session');
  });

  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets('closing search clears the hidden query (FE-COMM-12)', (
    tester,
  ) async {
    await _pumpMyReports(tester);
    await tester.tap(find.byTooltip('내 제보 검색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '가격표');
    await tester.pumpAndSettle();
    expect(find.text('승인 식당'), findsNothing);

    await tester.tap(find.byTooltip('내 제보 검색'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('승인 식당'), findsOneWidget);
    expect(find.text('검토 식당'), findsOneWidget);
  });

  testWidgets('pending tab no longer claims there are no pending reports '
      '(FE-COMM-13) and an empty needs-edit tab is hidden (FE-COMM-22)', (
    tester,
  ) async {
    await _pumpMyReports(tester);
    expect(find.text('보완 요청'), findsNothing);

    await tester.tap(find.text('검토 중').first);
    await tester.pumpAndSettle();
    expect(find.text('검토 식당'), findsOneWidget);
    expect(find.text('검토 중인 제보가 없어요'), findsNothing);
    expect(find.text('이전 검토 내역'), findsNothing);
  });

  testWidgets(
    'long menu names stay inside the 320px report card (FE-COMM-17)',
    (tester) async {
      await _pumpMyReports(tester);
      expect(tester.takeException(), isNull);
      final menu = tester.widget<Text>(find.textContaining('아주 긴 이름의'));
      expect(menu.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets('long address and menu stay inside the completion card '
      '(FE-COMM-17)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(userReportsProvider.notifier).setReports([
      UserReportStatus.fromJson(_reports.first),
    ]);
    final router = GoRouter(
      initialLocation: '${AppRoutes.reportComplete}?id=pending-1',
      routes: [
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
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_longAddress), findsOneWidget);
    expect(
      tester.getRect(find.text(_longAddress)).right,
      lessThanOrEqualTo(320),
    );
  });
}
