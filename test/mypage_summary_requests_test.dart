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

class _CountingReports extends ReportService {
  _CountingReports() : super(MockClient((_) async => http.Response('', 500)));

  var fetches = 0;

  @override
  Future<List<UserReportStatus>?> fetchMyReports() async {
    fetches++;
    return const [];
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('one mypage load reads my reports once for list and count', (
    tester,
  ) async {
    await ApiClient.setSessionToken('active-token');
    addTearDown(() => ApiClient.setSessionToken(null));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reports = _CountingReports();
    final paths = <String>[];

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
        await tester.pumpAndSettle();
      },
      () => MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          request.url.path == '/api/favorites' ? '[]' : '{}',
          200,
        );
      }),
    );

    expect(reports.fetches, 1);
    expect(paths, isNot(contains('/api/report/my')));
  });
}
