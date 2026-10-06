import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/presentation/screens/visit_verification_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StoreSideGeolocator extends GeolocatorPlatform {
  _StoreSideGeolocator(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

Store _store({required bool free, String price = '0'}) => Store(
  id: 'store-free',
  storeName: '무료 시식 가게',
  address: '서울 중구',
  phoneNumber: '',
  industry: '한식',
  menu1: '시식 국수',
  price1: price,
  free1: free,
  menu2: '',
  price2: '',
  menu3: '',
  price3: '',
  menu4: '',
  price4: '',
  latitude: 37.5665,
  longitude: 126.978,
  source: 'GOV',
);

void main() {
  late GeolocatorPlatform originalGeolocator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('visit-session');
    originalGeolocator = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _StoreSideGeolocator(37.5665, 126.978);
  });

  tearDown(() async {
    GeolocatorPlatform.instance = originalGeolocator;
    await ApiClient.setSessionToken(null);
  });

  Future<List<Map<String, dynamic>>> recordVisit(
    WidgetTester tester,
    Store store,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final posted = <Map<String, dynamic>>[];
    final router = GoRouter(
      initialLocation: AppRoutes.visitVerification,
      routes: [
        GoRoute(
          path: AppRoutes.visitVerification,
          builder: (_, _) => VisitVerificationScreen(store: store),
        ),
        GoRoute(
          path: AppRoutes.visitVerificationComplete,
          builder: (_, state) => Text(
            '완료 ${(state.extra as Map<String, dynamic>)['price']}원',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('현재 위치 확인'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ActionChip).first);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('방문 기록하기'));
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (request.method == 'POST' && request.url.path == '/api/visits') {
        posted.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'savedAmount': 0}), 200);
      }
      return http.Response(
        jsonEncode({'savedAmount': 0, 'referencePriceAvailable': false}),
        200,
      );
    }));
    return posted;
  }

  testWidgets('an approved free menu can be recorded as 0원 by location', (
    tester,
  ) async {
    final posted = await recordVisit(tester, _store(free: true));

    expect(posted, hasLength(1));
    expect(posted.single['price'], 0);
    expect(posted.single['verificationMethod'], 'LOCATION');
    expect(find.text('완료 0원'), findsOneWidget);
    expect(find.text('결제 금액을 입력해주세요.'), findsNothing);
  });

  testWidgets('a paid menu still cannot be recorded without an amount', (
    tester,
  ) async {
    final posted = await recordVisit(tester, _store(free: false));

    expect(posted, isEmpty);
    expect(find.text('결제 금액을 입력해주세요.'), findsOneWidget);
  });
}
