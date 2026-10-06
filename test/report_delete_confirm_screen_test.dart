import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/system/presentation/screens/report_delete_confirm_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('test-session');
  });

  tearDown(() async {
    await ApiClient.setSessionToken(null);
  });

  testWidgets('removes local report state only after the delete API succeeds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late http.Request capturedRequest;
    final service = ReportService(
      MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'success': true, 'id': 'report-1', 'deletedImages': 1}),
          200,
        );
      }),
    );
    const report = UserReportStatus(
      id: 'report-1',
      store: '테스트 식당',
      menu: '김치찌개 6,000원',
      status: '승인 완료',
      statusColor: 0xFF10B981,
      statusBg: 0xFFE8F8F1,
      textColor: 0xFF047857,
    );
    final container = ProviderContainer(
      overrides: [reportServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.read(userReportsProvider.notifier).setReports([report]);
    final profile = container.read(userProfileProvider);
    container.read(userProfileProvider.notifier).state = profile.copyWith(
      reportCount: 1,
    );

    final router = GoRouter(
      initialLocation: '/delete',
      routes: [
        GoRoute(
          path: '/delete',
          builder: (_, _) => const ReportDeleteConfirmScreen(report: report),
        ),
        GoRoute(
          path: AppRoutes.myReportsV2,
          builder: (_, _) => const Scaffold(body: Text('내 제보 목록')),
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
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();

    expect(capturedRequest.method, 'DELETE');
    expect(capturedRequest.url.path, '/api/report/store/report-1');
    expect(container.read(userReportsProvider), isEmpty);
    expect(container.read(userProfileProvider).reportCount, 0);
    expect(find.text('내 제보 목록'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(360, 640)]) {
    testWidgets('dialog buttons stay inside a ${size.width.toInt()}px screen '
        '(FE-COMM-8)', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const report = UserReportStatus(
        id: 'report-1',
        store: '아주 긴 이름을 가진 테스트 식당 본점',
        menu: '김치찌개 6,000원',
        status: '검토 중',
        statusColor: 0xFFF59E0B,
        statusBg: 0xFFFFF3EA,
        textColor: 0xFF92400E,
      );
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ReportDeleteConfirmScreen(report: report)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final label in ['취소', '삭제하기', '제보를 삭제할까요?']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(size.width), reason: label);
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: label);
      }
      expect(find.textContaining('복구할 수 없어요'), findsNothing);
      expect(find.textContaining('되돌릴 수 없어요'), findsOneWidget);
    });
  }

  testWidgets('system back is blocked while deleting and the list still '
      'updates afterwards (FE-COMM-26)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final response = Completer<http.Response>();
    final service = ReportService(MockClient((_) => response.future));
    const report = UserReportStatus(
      id: 'report-2',
      store: '테스트 식당',
      menu: '',
      status: '검토 중',
      statusColor: 0xFFF59E0B,
      statusBg: 0xFFFFF3EA,
      textColor: 0xFF92400E,
    );
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
          builder: (_, _) => const Scaffold(body: Text('제보 상세')),
        ),
        GoRoute(
          path: '/delete',
          builder: (_, _) => const ReportDeleteConfirmScreen(report: report),
        ),
        GoRoute(
          path: AppRoutes.myReportsV2,
          builder: (_, _) => const Scaffold(body: Text('내 제보 목록')),
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
    router.push('/delete');
    await tester.pumpAndSettle();

    await tester.tap(find.text('삭제하기'));
    await tester.pump();
    expect(find.text('삭제 중...'), findsOneWidget);

    // 진행 표시가 계속 움직이므로 pumpAndSettle 대신 몇 프레임만 넘깁니다.
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('삭제 중...'), findsOneWidget);
    expect(find.byType(ReportDeleteConfirmScreen), findsOneWidget);
    expect(find.text('제보 상세'), findsNothing);

    response.complete(
      http.Response(
        jsonEncode({'success': true, 'id': 'report-2', 'deletedImages': 0}),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(userReportsProvider), isEmpty);
    expect(find.text('내 제보 목록'), findsOneWidget);
  });
}
