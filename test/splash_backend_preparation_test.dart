import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/screens/splash_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/user_profile_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await ApiClient.setSessionToken('test-session');
  });

  tearDown(() async {
    await ApiClient.setSessionToken(null);
  });

  testWidgets('프로필 응답을 기다리는 동안 서비스 준비 화면을 빠르게 표시한다', (tester) async {
    final response = Completer<Map<String, dynamic>?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupProfileLoaderProvider.overrideWithValue(() => response.future),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('서비스를 준비하고 있어요'), findsOneWidget);
    expect(find.textContaining('무료 서버'), findsNothing);

    response.completeError(const UserProfileLoadException('프로필 조회 실패'));
    await tester.pump();
    await tester.pump();

    expect(find.text('연결이 평소보다 늦어지고 있어요'), findsOneWidget);
    expect(find.text('다시 연결'), findsOneWidget);
  });
}
