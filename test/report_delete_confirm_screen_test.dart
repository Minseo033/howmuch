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
}
