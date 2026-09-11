@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/location/browser_location.dart';
import 'package:howmuch/features/auth/presentation/screens/permission_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

void main() {
  late JSFunction originalRequest;
  late JSFunction success;
  late JSFunction failure;
  late web.PositionOptions options;
  var calls = 0;

  void allow() {
    success.callAsFunction(
      null,
      {
        'coords': {
          'latitude': 37.5665,
          'longitude': 126.9780,
          'accuracy': 25,
          'altitude': null,
          'altitudeAccuracy': null,
          'heading': null,
          'speed': null,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }.jsify(),
    );
  }

  setUp(() {
    calls = 0;
    SharedPreferences.setMockInitialValues({});
    originalRequest = web.window.navigator.geolocation.getProperty<JSFunction>(
      'getCurrentPosition'.toJS,
    );
    web.window.navigator.geolocation.setProperty(
      'getCurrentPosition'.toJS,
      ((JSFunction onSuccess, JSFunction onError, web.PositionOptions config) {
        calls++;
        success = onSuccess;
        failure = onError;
        options = config;
      }).toJS,
    );
  });

  tearDown(() {
    web.window.navigator.geolocation.setProperty(
      'getCurrentPosition'.toJS,
      originalRequest,
    );
  });

  test('starts synchronously and shares one pending browser prompt', () async {
    final first = requestBrowserLocation();
    expect(
      calls,
      1,
      reason: 'No async permission query before browser request',
    );
    final second = requestBrowserLocation();
    expect(identical(first, second), isTrue);
    expect(calls, 1);
    expect(options.timeout, 15000, reason: 'Browser timeout uses milliseconds');
    expect(options.maximumAge, 120000);
    allow();
    final position = await first;
    expect(position.latitude, 37.5665);
    expect(position.longitude, 126.9780);
    expect(position.accuracy, 25);
    expect(position.altitude, 0);
  });

  for (final (code, matcher) in [
    (1, isA<PermissionDeniedException>()),
    (2, isA<PositionUpdateException>()),
    (3, isA<TimeoutException>()),
  ]) {
    test('browser error $code retains its cause and allows retry', () async {
      final request = requestBrowserLocation();
      final result = expectLater(request, throwsA(matcher));
      failure.callAsFunction(
        null,
        {'code': code, 'message': 'Browser location error'}.jsify(),
      );
      await result;
      final retry = requestBrowserLocation();
      expect(calls, 2);
      allow();
      expect((await retry).latitude, 37.5665);
    });
  }

  testWidgets('startup tap waits for permission and prevents duplicate taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: PermissionSetupScreen()),
        ),
        GoRoute(
          path: AppRoutes.homeAiFab,
          builder: (_, _) =>
              const Scaffold(body: Text('Home after permission')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('앱 시작하기'));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('권한 응답을 기다리고 있어요…'), findsOneWidget);
    expect(find.text('Home after permission'), findsNothing);
    await tester.tap(find.text('권한 응답을 기다리고 있어요…'));
    expect(calls, 1);
    allow();
    await tester.pumpAndSettle();
    expect(find.text('Home after permission'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });
}
