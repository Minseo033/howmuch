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
      for (final label in ['취소', '삭제하기', '새 매장 제보를 삭제할까요?']) {
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(size.width), reason: label);
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: label);
      }
      expect(find.textContaining('복구할 수 없어요'), findsNothing);
      expect(find.textContaining('되돌릴 수 없어요'), findsOneWidget);
    });
  }

  Future<void> pumpDialog(WidgetTester tester, Map<String, Object> json) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReportDeleteConfirmScreen(
            report: UserReportStatus.fromJson(json),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('an info report names what is deleted and that its result '
      'notice goes too (QA #16, #56)', (tester) async {
    await pumpDialog(tester, {
      'id': 'info-1',
      'storeId': 'store-hak',
      'storeName': '동양미래대학교 학식당',
      'reportType': 'STORE_INFO',
      'changeType': 'other',
      'menu1': '한식',
      'price1': '6500',
      'status': 'APPROVED',
      'resolution': 'NO_CHANGE',
      'createdAt': '2026-10-07T02:44:00Z',
    });

    expect(find.text('정보 오류 신고를 삭제할까요?'), findsOneWidget);
    expect(find.text('동양미래대학교 학식당'), findsOneWidget);
    expect(find.text('신고 유형 기타'), findsOneWidget);
    expect(find.text('2026.10.07 · 수정 없음'), findsOneWidget);
    // 같은 매장의 새 매장 제보와 똑같아 보이던 대표 메뉴는 보이지 않습니다.
    expect(find.textContaining('6,500원'), findsNothing);
    expect(find.textContaining('신고 기록만 삭제하며'), findsOneWidget);
    expect(find.textContaining('이 신고와 관련된 알림도 알림함에서'), findsOneWidget);
    expect(find.textContaining('탐색'), findsNothing);
  });

  testWidgets('a rejected price change speaks of a report, not an applied '
      'correction (QA #16, #56)', (tester) async {
    await pumpDialog(tester, {
      'id': 'price-1',
      'storeId': 'store-hak',
      'storeName': '동양미래대학교 학식당',
      'changeType': 'rise',
      'menu1': '라면',
      'price1': '4500',
      'status': 'REJECTED',
      'rejectReason': '사진으로 확인할 수 없어요.',
      'createdAt': '2026-10-07T02:43:00Z',
    });

    expect(find.text('가격 변동 제보를 삭제할까요?'), findsOneWidget);
    expect(find.text('가격 인상 · 라면 4,500원'), findsOneWidget);
    expect(find.text('2026.10.07 · 반려'), findsOneWidget);
    expect(find.textContaining('제보 기록만 삭제하며'), findsOneWidget);
    expect(find.textContaining('신고 기록'), findsNothing);
    expect(find.textContaining('반영된 수정'), findsNothing);
    expect(find.textContaining('이 제보와 관련된 알림도 알림함에서'), findsOneWidget);
    // 반려된 제보는 탐색에 올라가 있지 않습니다.
    expect(find.textContaining('탐색'), findsNothing);
  });

  testWidgets('an approved new store warns about the map, the feed post and '
      'its notices (QA #16, #56)', (tester) async {
    await pumpDialog(tester, {
      'id': 'new-1',
      'storeName': '동양미래대학교 학식당',
      'menu1': '한식',
      'price1': '6500',
      'status': 'APPROVED',
      'createdAt': '2026-09-01T03:00:00Z',
    });

    expect(find.text('새 매장 제보를 삭제할까요?'), findsOneWidget);
    expect(find.text('대표 메뉴 한식 6,500원'), findsOneWidget);
    expect(find.text('2026.09.01 · 승인 완료'), findsOneWidget);
    expect(find.textContaining('지도에 등록된 이 매장도 함께 사라져요'), findsOneWidget);
    expect(find.textContaining('탐색에 올라간 글의 댓글·반응도'), findsOneWidget);
    expect(find.textContaining('이 제보와 관련된 알림도 알림함에서'), findsOneWidget);
  });

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
