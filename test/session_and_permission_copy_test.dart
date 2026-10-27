import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/auth/presentation/screens/permission_setup_screen.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/system/presentation/screens/session_expired_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingLoginService extends KakaoLoginService {
  _PendingLoginService(super.ref);

  final pending = Completer<KakaoLoginResult>();
  var loginCalls = 0;
  var clearCalls = 0;

  @override
  Future<KakaoLoginResult> login({bool navigate = true}) {
    loginCalls++;
    return pending.future;
  }

  @override
  Future<void> clearLocalSession({bool unregisterDevice = true}) async {
    clearCalls++;
  }
}

void _mobileViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('session expired re-login ignores taps while signing in', (
    tester,
  ) async {
    _mobileViewport(tester);
    late _PendingLoginService service;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kakaoLoginServiceProvider.overrideWith(
            (ref) => service = _PendingLoginService(ref),
          ),
        ],
        child: const MaterialApp(home: SessionExpiredScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('카카오로 다시 로그인'));
    await tester.pump();
    expect(find.text('로그인 중…'), findsOneWidget);
    await tester.tap(find.text('로그인 중…'));
    await tester.tap(find.text('나중에 할게요'));
    await tester.pump();

    expect(service.loginCalls, 1);
    expect(service.clearCalls, 0, reason: 'leaving mid-login is blocked');

    service.pending.complete(
      const KakaoLoginResult(KakaoLoginStatus.cancelled),
    );
    await tester.pump();
    expect(find.text('카카오로 다시 로그인'), findsOneWidget);
  });

  testWidgets('permission setup labels every permission as optional', (
    tester,
  ) async {
    _mobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PermissionSetupScreen())),
    );
    await tester.pump();

    expect(find.text('위치 권한 (선택)'), findsOneWidget);
    expect(find.text('알림 권한 (선택)'), findsOneWidget);
    expect(find.text('사진 접근 (선택)'), findsOneWidget);
    expect(find.textContaining('(필수)'), findsNothing);
    expect(find.textContaining('제보 결과'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
