import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/mypage/presentation/screens/withdrawal_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingLoginService extends KakaoLoginService {
  _RecordingLoginService(super.ref);

  final calls = <String>[];

  @override
  Future<void> unlinkKakaoAfterWithdrawal() async => calls.add('unlink');

  @override
  Future<void> clearLocalSession({bool unregisterDevice = true}) async =>
      calls.add('clear');
}

Future<_RecordingLoginService Function()> _pumpWithdrawal(
  WidgetTester tester,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      kakaoLoginServiceProvider.overrideWith(
        (ref) => _RecordingLoginService(ref),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: AppRoutes.withdrawal,
    routes: [
      GoRoute(
        path: AppRoutes.withdrawal,
        builder: (_, _) => const WithdrawalScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('로그인 화면')),
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
  return () =>
      container.read(kakaoLoginServiceProvider) as _RecordingLoginService;
}

Future<void> _confirmWithdrawal(WidgetTester tester) async {
  final consent = find.byKey(const ValueKey('withdrawal-consent'));
  await tester.ensureVisible(consent);
  await tester.pumpAndSettle();
  await tester.tap(consent);
  await tester.pumpAndSettle();
  await tester.tap(find.text('탈퇴하기').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('탈퇴하기').last);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('session-1');
  });
  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets('a timed-out withdrawal that the server accepted completes', (
    tester,
  ) async {
    final requests = <String>[];
    await http.runWithClient(
      () async {
        final service = await _pumpWithdrawal(tester);
        await _confirmWithdrawal(tester);
        await tester.pumpAndSettle();

        expect(requests, ['DELETE /api/user', 'GET /api/user/profile']);
        expect(service().calls, ['unlink', 'clear']);
        expect(find.text('로그인 화면'), findsOneWidget);
        expect(find.textContaining('회원 탈퇴 요청이 접수됐어요'), findsOneWidget);
      },
      () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.method == 'DELETE') {
          throw TimeoutException('slow deletion');
        }
        // The session was revoked by the withdrawal that is still running.
        return http.Response('', 401);
      }),
    );
  });

  testWidgets('a timed-out withdrawal the server never started can retry', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        final service = await _pumpWithdrawal(tester);
        await _confirmWithdrawal(tester);
        await tester.pumpAndSettle();

        expect(service().calls, isEmpty);
        expect(find.text('로그인 화면'), findsNothing);
        expect(find.textContaining('탈퇴 요청이 처리되지 않았어요'), findsOneWidget);
        expect(find.text('탈퇴하기'), findsOneWidget, reason: 'button is usable');
      },
      () => MockClient((request) async {
        if (request.method == 'DELETE') throw TimeoutException('slow');
        return http.Response('{"nickname":"saver"}', 200);
      }),
    );
  });

  testWidgets('a successful withdrawal unlinks Kakao before leaving', (
    tester,
  ) async {
    await http.runWithClient(() async {
      final service = await _pumpWithdrawal(tester);
      await _confirmWithdrawal(tester);
      await tester.pumpAndSettle();

      expect(service().calls, ['unlink', 'clear']);
      expect(find.text('회원 탈퇴가 완료되었어요.'), findsOneWidget);
    }, () => MockClient((_) async => http.Response('{"uid":"kakao:1"}', 200)));
  });

  testWidgets('no withdrawal reason is chosen for the user', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpWithdrawal(tester);

    for (final reason in ['원하는 매장 정보가 부족해요', '가격 정보가 정확하지 않아요', '기타']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(reason)),
        isSemantics(isChecked: false, isInMutuallyExclusiveGroup: true),
      );
    }
    semantics.dispose();
  });
}
