import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/screens/mypage_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 내 제보 조회 결과를 테스트가 정한 시점에 돌려줍니다.
class _ControlledReports extends ReportService {
  _ControlledReports() : super(MockClient((_) async => http.Response('', 500)));

  final response = Completer<List<UserReportStatus>?>();

  @override
  Future<List<UserReportStatus>?> fetchMyReports() => response.future;
}

UserReportStatus _report(String id, String store) => UserReportStatus.fromJson({
  'id': id,
  'storeName': store,
  'menu1': '한식',
  'price1': '6500',
  'status': 'REJECTED',
  'createdAt': '2026-09-23T03:00:00Z',
});

/// 프로필·절약·찜 요청은 빈 응답으로 바로 끝내고 내 제보만 [reports]로 조절합니다.
Future<void> _withMypage(
  WidgetTester tester,
  ReportService reports,
  Future<void> Function() body,
) async {
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
            reportServiceProvider.overrideWithValue(reports),
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
      await body();
    },
    () => MockClient(
      (request) async => http.Response(
        request.url.path == '/api/favorites' ? '[]' : '{}',
        200,
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('active-token');
  });

  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets('MY shows a loading state until my reports arrive instead of '
      'claiming there are none (QA #18)', (tester) async {
    final reports = _ControlledReports();
    await _withMypage(tester, reports, () async {
      await tester.pump();
      await tester.pump();
      expect(find.text('내 제보를 불러오는 중이에요'), findsOneWidget);
      expect(find.text('아직 제보한 내역이 없어요'), findsNothing);
      expect(find.text('진행 중인 제보가 없어요'), findsNothing);

      reports.response.complete([
        _report('report-1', '정장군숯불구이전문점'),
        _report('report-2', '가이오청년밥상'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('내 제보를 불러오는 중이에요'), findsNothing);
      expect(find.text('정장군숯불구이전문점'), findsOneWidget);
      expect(find.text('가이오청년밥상'), findsOneWidget);
    });
  });

  testWidgets('MY tells an empty report list apart from a failed load '
      '(QA #18)', (tester) async {
    final empty = _ControlledReports()..response.complete(const []);
    await _withMypage(tester, empty, () async {
      await tester.pumpAndSettle();
      expect(find.text('아직 제보한 내역이 없어요'), findsOneWidget);
      expect(find.text('내 제보를 불러오지 못했어요'), findsNothing);
    });

    final failed = _ControlledReports()..response.complete(null);
    await _withMypage(tester, failed, () async {
      await tester.pumpAndSettle();
      expect(find.text('내 제보를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('아직 제보한 내역이 없어요'), findsNothing);
    });
  });

  testWidgets('the profile summary counts reports, not stores (QA #19)', (
    tester,
  ) async {
    // 같은 매장에 두 번 제보해도 내 제보 목록처럼 두 건으로 셉니다.
    final reports = _ControlledReports()
      ..response.complete([
        _report('report-1', '동양미래대학교 학식당'),
        _report('report-2', '동양미래대학교 학식당'),
        _report('report-3', '노랑통닭'),
      ]);
    await _withMypage(tester, reports, () async {
      await tester.pumpAndSettle();
      final metric = find.byKey(const ValueKey('mypage-metric-report-count'));
      expect(
        find.descendant(of: metric, matching: find.text('3건')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: metric, matching: find.text('내 제보')),
        findsOneWidget,
      );
      expect(find.text('제보 매장'), findsNothing);
    });
  });
}
