import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/screens/mypage_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Reports extends ReportService {
  _Reports() : super(MockClient((_) async => http.Response('', 500)));

  var fetches = 0;

  @override
  Future<List<UserReportStatus>?> fetchMyReports() async {
    fetches++;
    return const [];
  }
}

http.Response _stats(int amount) => http.Response.bytes(
  utf8.encode(jsonEncode({'totalSavedAmount': amount, 'totalVisits': 1})),
  200,
);

http.Response _jsonResponse(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

AuthState _auth(String session) => AuthState(
  isLoggedIn: true,
  provider: '카카오',
  email: 'saver@example.com',
  sessionToken: session,
);

Future<GoRouter> _pumpTabs(WidgetTester tester, _Reports reports) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: AppRoutes.mypage,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => shell,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.mypage,
                builder: (_, _) => const MypageScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const Scaffold(body: Text('홈')),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (_, _) => const Scaffold(body: Text('프로필 수정')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reportServiceProvider.overrideWithValue(reports),
        authStateProvider.overrideWith((ref) => _auth('session-a')),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('session-a');
  });
  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets(
    'a fresh MY tab return keeps numbers and makes no summary calls',
    (tester) async {
      final paths = <String>[];
      final reports = _Reports();
      await http.runWithClient(
        () async {
          final router = await _pumpTabs(tester, reports);
          expect(find.text('15,000원'), findsOneWidget);
          expect(paths.length, 3, reason: '$paths');
          expect(reports.fetches, 1);

          router.go(AppRoutes.home);
          await tester.pumpAndSettle();
          router.go(AppRoutes.mypage);
          await tester.pump();
          expect(find.text('15,000원'), findsOneWidget);
          await tester.pumpAndSettle();
          expect(paths.length, 3, reason: '$paths');
          expect(reports.fetches, 1);
        },
        () => MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/api/savings/stats') return _stats(15000);
          return _jsonResponse(
            request.url.path == '/api/favorites'
                ? []
                : {'nickname': '알뜰한 민', 'email': 'saver@example.com'},
          );
        }),
      );
    },
  );

  testWidgets('returning from profile edit force refreshes the summary', (
    tester,
  ) async {
    final paths = <String>[];
    final reports = _Reports();
    await http.runWithClient(
      () async {
        final router = await _pumpTabs(tester, reports);
        expect(paths.length, 3);
        router.push(AppRoutes.profileEdit);
        await tester.pumpAndSettle();
        router.pop();
        await tester.pumpAndSettle();
        expect(paths.length, 6, reason: '$paths');
        expect(reports.fetches, 2);
      },
      () => MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/api/savings/stats') return _stats(15000);
        return _jsonResponse(
          request.url.path == '/api/favorites'
              ? []
              : {'nickname': '알뜰한 민', 'email': 'saver@example.com'},
        );
      }),
    );
  });

  testWidgets('an invalidated MY refresh keeps its prior numbers until ready', (
    tester,
  ) async {
    final refreshed = Completer<http.Response>();
    var savingsCalls = 0;
    final reports = _Reports();
    await http.runWithClient(
      () async {
        final router = await _pumpTabs(tester, reports);
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
        ApiClient.invalidateReadCache();
        router.go(AppRoutes.mypage);
        await tester.pumpAndSettle();
        expect(find.text('15,000원'), findsOneWidget);
        expect(savingsCalls, 2);
        expect(reports.fetches, 2);

        refreshed.complete(_stats(18000));
        await tester.pumpAndSettle();
        expect(find.text('18,000원'), findsOneWidget);
        expect(find.text('15,000원'), findsNothing);
      },
      () => MockClient((request) async {
        if (request.url.path == '/api/savings/stats') {
          return ++savingsCalls == 1 ? _stats(15000) : refreshed.future;
        }
        return _jsonResponse(
          request.url.path == '/api/favorites'
              ? []
              : {'email': 'saver@example.com'},
        );
      }),
    );
  });

  testWidgets('an old account response cannot replace the new MY summary', (
    tester,
  ) async {
    final previousAccount = Completer<http.Response>();
    final newAccount = Completer<http.Response>();
    var accountACalls = 0;
    await http.runWithClient(
      () async {
        final router = await _pumpTabs(tester, _Reports());
        expect(find.text('15,000원'), findsOneWidget);
        router.go(AppRoutes.home);
        await tester.pumpAndSettle();
        ApiClient.invalidateReadCache();
        router.go(AppRoutes.mypage);
        await tester.pumpAndSettle();

        await ApiClient.setSessionToken('session-b');
        ProviderScope.containerOf(
          tester.element(find.byType(MypageScreen)),
        ).read(authStateProvider.notifier).state = _auth(
          'session-b',
        );
        await tester.pumpAndSettle();
        expect(find.text('15,000원'), findsNothing);

        newAccount.complete(_stats(22000));
        await tester.pumpAndSettle();
        expect(find.text('22,000원'), findsOneWidget);
        previousAccount.complete(_stats(99000));
        await tester.pumpAndSettle();
        expect(find.text('22,000원'), findsOneWidget);
        expect(find.text('99,000원'), findsNothing);
      },
      () => MockClient((request) async {
        if (request.url.path == '/api/savings/stats') {
          if (request.headers['Authorization'] == 'Bearer session-b') {
            return newAccount.future;
          }
          return ++accountACalls == 1 ? _stats(15000) : previousAccount.future;
        }
        return _jsonResponse(
          request.url.path == '/api/favorites'
              ? []
              : {'email': 'saver@example.com'},
        );
      }),
    );
  });
}
