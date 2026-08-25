import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/core/network/backend_warmup_service.dart';
import 'package:howmuch/features/auth/presentation/screens/splash_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await ApiClient.setSessionToken('test-session');
  });

  tearDown(() async {
    await ApiClient.setSessionToken(null);
  });

  testWidgets('백엔드 응답을 기다리는 동안 서비스 준비 화면을 표시한다', (tester) async {
    final response = Completer<http.Response>();
    final service = BackendWarmupService(
      client: MockClient((request) => response.future),
    );
    addTearDown(service.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [backendWarmupServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2700));

    expect(find.text('서비스를 준비하고 있어요'), findsOneWidget);
    expect(find.textContaining('무료 서버'), findsNothing);

    response.complete(http.Response('{}', 503));
    await tester.pump();
    await tester.pump();

    expect(find.text('연결이 평소보다 늦어지고 있어요'), findsOneWidget);
    expect(find.text('다시 연결'), findsOneWidget);
  });
}
