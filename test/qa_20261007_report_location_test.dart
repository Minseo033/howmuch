import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/features/community/presentation/screens/report_create_screen.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';

/// QA 2026-10-07 #34: the report store search said '위치 권한이 없어' whenever
/// it had no position, even with the permission granted.
void main() {
  group('store search location notice', () {
    testWidgets('only a refused permission is described as one', (
      tester,
    ) async {
      await _openStoreSearch(
        tester,
        locate: () async => throw const ReportLocationUnavailable(
          ReportLocationIssue.permissionDenied,
        ),
      );
      expect(find.text('위치 권한이 없어 검색 관련도순으로 보여드려요.'), findsOneWidget);
    });

    testWidgets('a position that did not come is not a missing permission', (
      tester,
    ) async {
      await _openStoreSearch(tester, locate: () async => null);
      expect(find.text('현재 위치를 확인하지 못해 검색 관련도순으로 보여드려요.'), findsOneWidget);
      expect(find.text('위치 권한이 없어 검색 관련도순으로 보여드려요.'), findsNothing);
    });

    testWidgets('location services turned off are named', (tester) async {
      await _openStoreSearch(
        tester,
        locate: () async => throw const ReportLocationUnavailable(
          ReportLocationIssue.serviceDisabled,
        ),
      );
      expect(find.text('위치 서비스가 꺼져 있어 검색 관련도순으로 보여드려요.'), findsOneWidget);
    });
  });

  group('a search typed while locating', () {
    testWidgets('waits for the position and is ordered by distance', (
      tester,
    ) async {
      final position = Completer<({double latitude, double longitude})?>();
      final searches = <String>[];
      await _openStoreSearch(
        tester,
        locate: () => position.future,
        searches: searches,
      );
      expect(find.text('현재 위치 확인 중…'), findsOneWidget);

      await tester.enterText(_searchField, '김밥천국');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));
      expect(searches, isEmpty, reason: 'no results ordered without location');

      position.complete((latitude: 37.55, longitude: 126.93));
      await tester.pumpAndSettle();
      expect(searches, ['김밥천국@37.55,126.93']);
      expect(find.text('현재 위치에서 가까운 순으로 보여드려요.'), findsOneWidget);
      expect(find.text('김밥천국 신촌점'), findsOneWidget);
    });

    testWidgets('does not wait more than a few seconds', (tester) async {
      final position = Completer<({double latitude, double longitude})?>();
      final searches = <String>[];
      await _openStoreSearch(
        tester,
        locate: () => position.future,
        searches: searches,
      );

      await tester.enterText(_searchField, '김밥천국');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(searches, ['김밥천국@-']);
      expect(find.text('현재 위치 확인 중…'), findsOneWidget);

      // A position that arrives later still reorders the results.
      position.complete((latitude: 37.55, longitude: 126.93));
      await tester.pumpAndSettle();
      expect(searches, ['김밥천국@-', '김밥천국@37.55,126.93']);
    });

    testWidgets('a store name typed before opening waits the same way', (
      tester,
    ) async {
      final searches = <String>[];
      await _openStoreSearch(
        tester,
        locate: () =>
            Completer<({double latitude, double longitude})?>().future,
        searches: searches,
        storeName: '김밥천국',
      );
      expect(searches, isEmpty);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(searches, ['김밥천국@-']);
    });
  });

  group('lookUpReportLocation', () {
    late GeolocatorPlatform original;
    setUp(() => original = GeolocatorPlatform.instance);
    tearDown(() {
      GeolocatorPlatform.instance = original;
      HomeMapScreen.globalUserPosition = null;
    });

    test('a granted permission without a fix in time is not a refusal', () {
      GeolocatorPlatform.instance = _FakeGeolocator(
        current: () => throw TimeoutException('no fix'),
      );
      expect(lookUpReportLocation(), completion(isNull));
    });

    test('a refused permission is reported as such', () {
      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.deniedForever,
      );
      expect(
        lookUpReportLocation(),
        throwsA(
          isA<ReportLocationUnavailable>().having(
            (error) => error.issue,
            'issue',
            ReportLocationIssue.permissionDenied,
          ),
        ),
      );
    });

    test('location services turned off are reported as such', () {
      GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);
      expect(
        lookUpReportLocation(),
        throwsA(
          isA<ReportLocationUnavailable>().having(
            (error) => error.issue,
            'issue',
            ReportLocationIssue.serviceDisabled,
          ),
        ),
      );
    });

    test('the home map position is used while it is recent', () async {
      final geolocator = _FakeGeolocator();
      GeolocatorPlatform.instance = geolocator;
      HomeMapScreen.globalUserPosition = _position(37.56, DateTime.now());
      final location = await lookUpReportLocation();
      expect(location?.latitude, 37.56);
      expect(geolocator.currentRequests, 0);
    });

    test('an old home map position is refreshed', () async {
      final geolocator = _FakeGeolocator(
        current: () => _position(37.57, DateTime.now()),
      );
      GeolocatorPlatform.instance = geolocator;
      HomeMapScreen.globalUserPosition = _position(
        37.40,
        DateTime.now().subtract(const Duration(minutes: 10)),
      );
      final location = await lookUpReportLocation();
      expect(location?.latitude, 37.57);
      expect(geolocator.currentRequests, 1);
    });
  });
}

final _searchField = find.byKey(const ValueKey('report-address-search-input'));

Future<void> _openStoreSearch(
  WidgetTester tester, {
  required LocationLookup locate,
  List<String>? searches,
  String? storeName,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: ReportCreateScreen(
          locationLookup: locate,
          placeSearch: (query, latitude, longitude) async {
            searches?.add(
              '$query@${latitude == null ? '-' : '$latitude,$longitude'}',
            );
            return [
              ReportPlaceSuggestion(
                name: latitude == null ? '김밥천국 울산점' : '김밥천국 신촌점',
                address: latitude == null ? '울산 남구' : '서울 서대문구',
                category: '음식점 > 분식',
              ),
            ];
          },
        ),
      ),
    ),
  );
  if (storeName != null) {
    await tester.enterText(find.byType(TextField).first, storeName);
  }
  await tester.tap(find.byTooltip('매장 검색'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Position _position(double latitude, DateTime timestamp) => Position(
  latitude: latitude,
  longitude: 126.93,
  timestamp: timestamp,
  accuracy: 20,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    Position Function()? current,
  }) : _current = current;

  final bool serviceEnabled;
  final LocationPermission permission;
  final Position Function()? _current;
  int currentRequests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    currentRequests++;
    final current = _current;
    if (current == null) throw StateError('no position in this test');
    return current();
  }
}
