import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/features/home/home_map_store_loader.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

const _compassChannel = EventChannel('hemanthraj/flutter_compass');

void main() {
  late _RecordingWebViewPlatform webViews;
  late GeolocatorPlatform originalGeolocator;
  late _FakeGeolocator geolocator;
  MockStreamHandlerEventSink? compass;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    webViews = _RecordingWebViewPlatform();
    WebViewPlatform.instance = webViews;
    originalGeolocator = GeolocatorPlatform.instance;
    geolocator = _FakeGeolocator();
    GeolocatorPlatform.instance = geolocator;
    compass = null;
    HomeMapScreen.setMapStores(const []);
    HomeMapScreen.setSearchCatalog(const []);
    HomeMapScreen.globalUserPosition = null;
    HomeMapScreen.hasDismissedLocationNotice = false;
    HomeMapScreen.clearSavedMapState();
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalGeolocator;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(_compassChannel, null);
    HomeMapScreen.globalUserPosition = null;
  });

  Future<_RecordingController> pumpHome(
    WidgetTester tester,
    HomeMapScreen screen,
  ) async {
    // Registered inside the test body so compass events follow fake time.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          _compassChannel,
          MockStreamHandler.inline(
            onListen: (_, events) {
              compass = events;
            },
          ),
        );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
    final controller = webViews.controllers.single;
    controller.send('Map Initialized on Mobile');
    await tester.pump();
    return controller;
  }

  Future<void> disposeHome(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  test('marker click payloads carry the rendered index and store ID', () {
    expect(parseMobileMarkerClick('{"index":3,"storeId":"store-9"}'), (
      index: 3,
      storeId: 'store-9',
    ));
    expect(parseMobileMarkerClick('2'), (index: 2, storeId: ''));
    expect(parseMobileMarkerClick('{"index":1.5,"storeId":"x"}'), isNull);
    expect(parseMobileMarkerClick('not a click'), isNull);
  });

  testWidgets(
    'a search marker opens the tapped store, not the card at that position',
    (tester) async {
      final far = _store('far', 35.1796, 129.0756, name: '부산 국밥');
      final near = _store('near', 37.5665, 126.978, name: '시청 국밥');
      final next = _store('next', 37.567, 126.979, name: '덕수궁 국밥');
      final controller = await pumpHome(
        tester,
        HomeMapScreen(
          storeLoader: _emptyLoader,
          initialSearchResult: buildSearchMapResult(
            query: '국밥',
            filter: const SearchFilter(),
            stores: [far, near, next],
          ),
        ),
      );
      expect(controller.scripts, contains('setSearchMode(true);'));

      controller.send(_bounds(37.5, 37.6, 126.9, 127.05));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        _renderedStoreIds(controller),
        ['near', 'next'],
        reason: 'only stores inside the viewport get markers',
      );

      controller.scripts.clear();
      controller.send(_click(0, 'near'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        controller.scripts,
        contains('setMapCenterFromSwipe(37.5665, 126.978);'),
        reason: 'the card list moved to the tapped store',
      );
      expect(
        controller.scripts.where((script) => script.contains('35.1796')),
        isEmpty,
        reason: 'the first search result outside the viewport is not opened',
      );
      expect(
        controller.scripts
            .where((script) => script.startsWith('highlightMarker('))
            .toSet(),
        {'highlightMarker(0);'},
        reason: 'the highlight uses the position among drawn markers',
      );

      controller.scripts.clear();
      controller.send(_click(1, 'store-no-longer-listed'));
      await tester.pump();
      expect(
        controller.scripts.last,
        'highlightMarker(0);',
        reason: 'an unknown marker leaves the selected store highlighted',
      );
      await disposeHome(tester);
    },
  );

  testWidgets(
    'a distant marker jumps the cards without panning past other stores',
    (tester) async {
      final stores = [
        for (var i = 0; i < 5; i++)
          _store('ai-$i', 37.56 + i / 1000, 126.97 + i / 1000, menu: '백반'),
      ];
      final controller = await pumpHome(
        tester,
        HomeMapScreen(
          storeLoader: _emptyLoader,
          initialRecommendation: AiMapRecommendationResult(
            storeIds: [for (final store in stores) store.id],
            stores: stores,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(_renderedStoreIds(controller), [
        for (final store in stores) store.id,
      ]);

      controller.scripts.clear();
      controller.send(_click(4, 'ai-4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        controller.scripts.where(
          (script) => script.startsWith('setMapCenterFromSwipe('),
        ),
        [
          'setMapCenterFromSwipe(${stores[4].latitude}, ${stores[4].longitude});',
        ],
      );
      await disposeHome(tester);
    },
  );

  testWidgets(
    'an AI result replaces the search and clearing it shows the plain map',
    (tester) async {
      final searchStore = _store('search', 37.5665, 126.978, name: '검색 국밥');
      final aiStore = _store('ai', 37.57, 126.98, name: 'AI 백반집', menu: '백반');
      final controller = await pumpHome(
        tester,
        HomeMapScreen(
          storeLoader: _emptyLoader,
          initialSearchResult: buildSearchMapResult(
            query: '국밥',
            filter: const SearchFilter(maxPrice: 10000),
            stores: [searchStore],
          ),
          initialRecommendation: AiMapRecommendationResult(
            storeIds: const ['ai'],
            stores: [aiStore],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('AI 추천 매장 1곳'), findsOneWidget);
      expect(find.text('국밥'), findsNothing, reason: 'the old query is gone');
      expect(find.text('10,000원 이하'), findsNothing);
      expect(controller.scripts, contains('setSearchMode(false);'));

      await tester.tap(find.text('전체보기'));
      await tester.pump();
      expect(find.text('가게명, 메뉴, 지역 검색'), findsOneWidget);
      expect(find.byType(HomeMapStoreCarousel), findsNothing);
      await disposeHome(tester);
    },
  );

  testWidgets('a viewport that is already loading is not requested again', (
    tester,
  ) async {
    final loads = <Completer<HomeMapStoreLoadResult>>[];
    Future<HomeMapStoreLoadResult> loader({
      required Map<String, double> bounds,
      required List<Store> cachedStores,
    }) {
      final load = Completer<HomeMapStoreLoadResult>();
      loads.add(load);
      return load.future;
    }

    final controller = await pumpHome(
      tester,
      HomeMapScreen(storeLoader: loader),
    );
    final cityHall = _bounds(37.55, 37.58, 126.96, 126.99);
    controller.send(cityHall);
    await tester.pump(const Duration(milliseconds: 350));
    expect(loads, hasLength(1));

    controller.send(cityHall);
    await tester.pump(const Duration(milliseconds: 350));
    expect(loads, hasLength(1), reason: 'the in-flight request is kept');

    loads.single.complete(
      HomeMapStoreLoadResult(
        stores: [_store('a', 37.56, 126.97)],
        hasFreshResponse: true,
      ),
    );
    await tester.pump();
    expect(_renderedStoreIds(controller), ['a']);
    expect(loads, hasLength(1));

    controller.send(_bounds(35.1, 35.2, 129.0, 129.1));
    await tester.pump(const Duration(milliseconds: 350));
    expect(loads, hasLength(2), reason: 'a different viewport still loads');
    loads.last.complete(
      const HomeMapStoreLoadResult(stores: [], hasFreshResponse: true),
    );
    await tester.pump();
    await disposeHome(tester);
  });

  testWidgets(
    'a failed viewport load offers a retry without blocking the map',
    (tester) async {
      var loads = 0;
      final controller = await pumpHome(
        tester,
        HomeMapScreen(
          storeLoader:
              ({
                required Map<String, double> bounds,
                required List<Store> cachedStores,
              }) async {
                loads++;
                return HomeMapStoreLoadResult(
                  stores: [_store('cached', 37.56, 126.97)],
                  hasFreshResponse: false,
                );
              },
        ),
      );
      controller.send(_bounds(37.55, 37.58, 126.96, 126.99));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('새 매장 정보를 불러오지 못했어요'), findsOneWidget);
      expect(_renderedStoreIds(controller), ['cached']);

      controller.send(_bounds(37.56, 37.59, 126.97, 127.0));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(loads, 2);
      expect(
        find.text('새 매장 정보를 불러오지 못했어요'),
        findsOneWidget,
        reason: 'one notice per failure streak',
      );

      controller.scripts.clear();
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      expect(controller.scripts, contains('requestBounds();'));
      await disposeHome(tester);
    },
  );

  testWidgets('a truncated viewport suggests zooming in once per streak', (
    tester,
  ) async {
    var truncated = true;
    final controller = await pumpHome(
      tester,
      HomeMapScreen(
        storeLoader:
            ({
              required Map<String, double> bounds,
              required List<Store> cachedStores,
            }) async => HomeMapStoreLoadResult(
              stores: [_store('dense', 37.56, 126.97)],
              hasFreshResponse: true,
              truncated: truncated,
            ),
      ),
    );
    const hint = '지도를 확대하면 매장이 더 보여요.';
    controller.send(_bounds(37.0, 38.0, 126.5, 127.5));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text(hint), findsOneWidget);

    // Entrance animation, display time, exit animation.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(hint), findsNothing);
    controller.send(_bounds(37.1, 38.1, 126.5, 127.5));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text(hint), findsNothing, reason: 'still the same streak');

    truncated = false;
    controller.send(_bounds(37.5, 37.6, 126.9, 127.0));
    await tester.pump(const Duration(milliseconds: 350));
    truncated = true;
    controller.send(_bounds(36.5, 37.5, 126.5, 127.5));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text(hint), findsOneWidget);
    await disposeHome(tester);
  });

  testWidgets('iOS ending the WebView process reloads the map where it was', (
    tester,
  ) async {
    final controller = await pumpHome(
      tester,
      const HomeMapScreen(storeLoader: _emptyLoader),
    );
    controller.send(
      _bounds(
        35.1,
        35.2,
        129.0,
        129.1,
        centerLat: 35.15,
        centerLng: 129.05,
        level: 6,
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.htmlLoads, hasLength(1));

    controller.navigationDelegate!.onWebResourceError!(
      const WebResourceError(
        errorCode: -1009,
        description: 'offline',
        errorType: WebResourceErrorType.connect,
      ),
    );
    expect(controller.htmlLoads, hasLength(1));

    controller.navigationDelegate!.onWebResourceError!(
      const WebResourceError(
        errorCode: 2,
        description: 'WebView content process was terminated.',
        errorType: WebResourceErrorType.webContentProcessTerminated,
        isForMainFrame: true,
      ),
    );
    await tester.pump();
    expect(controller.htmlLoads, hasLength(2));
    expect(
      controller.htmlLoads.last,
      contains('new kakao.maps.LatLng(35.15, 129.05), level: 6'),
    );
    await disposeHome(tester);
  });

  testWidgets('a marker tap that also reaches the map keeps its card open', (
    tester,
  ) async {
    final controller = await pumpHome(
      tester,
      HomeMapScreen(
        storeLoader:
            ({
              required Map<String, double> bounds,
              required List<Store> cachedStores,
            }) async => HomeMapStoreLoadResult(
              stores: [_store('a', 37.56, 126.97, name: '시청 백반')],
              hasFreshResponse: true,
            ),
      ),
    );
    controller.send(_bounds(37.55, 37.58, 126.96, 126.99));
    await tester.pump(const Duration(milliseconds: 350));

    controller.send(_click(0, 'a'));
    controller.send('MAP_CLICK');
    await tester.pump();
    expect(find.byType(HomeMapStoreSummaryCard), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    controller.send('MAP_CLICK');
    await tester.pump();
    expect(find.byType(HomeMapStoreSummaryCard), findsNothing);
    await disposeHome(tester);
  });

  testWidgets('a press on the store card that also reaches the map keeps it', (
    tester,
  ) async {
    final controller = await pumpHome(
      tester,
      HomeMapScreen(
        storeLoader:
            ({
              required Map<String, double> bounds,
              required List<Store> cachedStores,
            }) async => HomeMapStoreLoadResult(
              stores: [_store('a', 37.56, 126.97, name: '시청 백반')],
              hasFreshResponse: true,
            ),
      ),
    );
    controller.send(_bounds(37.55, 37.58, 126.96, 126.99));
    await tester.pump(const Duration(milliseconds: 350));
    controller.send(_click(0, 'a'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final card = find.byType(HomeMapStoreSummaryCard);
    expect(card, findsOneWidget);

    final press = await tester.startGesture(tester.getCenter(card));
    controller.send('MAP_CLICK');
    await tester.pump();
    expect(card, findsOneWidget, reason: 'the press reached the map below');

    await press.up();
    controller.send('MAP_CLICK');
    await tester.pump();
    expect(card, findsOneWidget, reason: 'the tap reached it on release');

    // The guard is measured on the wall clock, like the location button's.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    controller.send('MAP_CLICK');
    await tester.pump();
    expect(card, findsNothing, reason: 'a background tap still closes it');
    await disposeHome(tester);
  });

  group('after another tab replaced home', () {
    Future<HomeMapStoreLoadResult> busanLoader({
      required Map<String, double> bounds,
      required List<Store> cachedStores,
    }) async => HomeMapStoreLoadResult(
      stores: [_store('busan', 35.15, 129.05, name: '부산 돼지국밥')],
      hasFreshResponse: true,
    );

    Future<void> moveToBusanAndOpenCard(WidgetTester tester) async {
      final first = await pumpHome(
        tester,
        HomeMapScreen(storeLoader: busanLoader),
      );
      await tester.pump(const Duration(milliseconds: 50));
      // The user drags and zooms the map to Busan, then opens a store card.
      first.send('MOVE_START');
      first.send(
        _bounds(
          35.1,
          35.2,
          129.0,
          129.1,
          centerLat: 35.15,
          centerLng: 129.05,
          level: 6,
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      first.send(_click(0, 'busan'));
      await tester.pump();
      expect(find.text('부산 돼지국밥'), findsOneWidget);
      await disposeHome(tester);
      webViews.controllers.clear();
    }

    testWidgets('the map reopens where the user left it with its card', (
      tester,
    ) async {
      await moveToBusanAndOpenCard(tester);

      final second = await pumpHome(
        tester,
        HomeMapScreen(storeLoader: busanLoader),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        second.htmlLoads.single,
        contains('new kakao.maps.LatLng(35.15, 129.05), level: 6'),
      );
      expect(
        second.scripts.where((script) => script.startsWith('setMapCenter(')),
        isEmpty,
        reason: 'the map must not jump back to the user',
      );
      expect(find.text('부산 돼지국밥'), findsOneWidget);

      // Closing the card is kept too.
      second.send('MAP_CLICK');
      await tester.pump();
      expect(find.text('부산 돼지국밥'), findsNothing);
      await disposeHome(tester);
      webViews.controllers.clear();
      await pumpHome(tester, HomeMapScreen(storeLoader: busanLoader));
      expect(find.text('부산 돼지국밥'), findsNothing);
      await disposeHome(tester);
    });

    testWidgets('an untouched map still opens at the user', (tester) async {
      final first = await pumpHome(
        tester,
        const HomeMapScreen(storeLoader: _emptyLoader),
      );
      await tester.pump(const Duration(milliseconds: 50));
      // The map reports a viewport, but the user never moved it.
      first.send(
        _bounds(37.54, 37.56, 126.98, 127.0, centerLat: 37.55, level: 4),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await disposeHome(tester);
      webViews.controllers.clear();

      final second = await pumpHome(
        tester,
        const HomeMapScreen(storeLoader: _emptyLoader),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        second.htmlLoads.single,
        contains('new kakao.maps.LatLng(37.5665, 126.978), level: 3'),
      );
      expect(second.scripts, contains('setMapCenter(37.5665, 126.978);'));
      await disposeHome(tester);
    });

    testWidgets('a result handed over by another screen moves the map', (
      tester,
    ) async {
      await moveToBusanAndOpenCard(tester);
      final aiStore = _store('ai', 37.57, 126.98, name: 'AI 백반집', menu: '백반');

      final second = await pumpHome(
        tester,
        HomeMapScreen(
          storeLoader: _emptyLoader,
          initialRecommendation: AiMapRecommendationResult(
            storeIds: const ['ai'],
            stores: [aiStore],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        second.htmlLoads.single,
        contains('new kakao.maps.LatLng(37.5665, 126.978), level: 3'),
      );
      expect(second.scripts, contains('setMapCenterFromSwipe(37.57, 126.98);'));
      expect(find.text('부산 돼지국밥'), findsNothing);
      await disposeHome(tester);
    });
  });

  testWidgets(
    'cheapest-first map results list the nearer store first at the same price',
    (tester) async {
      // Same price; the names sort the other way round from the distances.
      final far = _store('far', 37.585, 126.995, name: '가 국밥');
      final middle = _store('middle', 37.575, 126.985, name: '나 국밥');
      final near = _store('near', 37.5666, 126.9781, name: '다 국밥');
      HomeMapScreen.setSearchCatalog([far, middle, near]);
      final semantics = tester.ensureSemantics();
      final controller = await pumpHome(
        tester,
        HomeMapScreen(
          storeLoader: _emptyLoader,
          initialSearchResult: buildSearchMapResult(
            query: '국밥',
            filter: const SearchFilter(maxPrice: 10000, sortOrder: '저렴한순'),
            stores: [near, middle, far],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Removing a filter on the map sorts the catalog again (QA #31).
      await tester.tap(find.bySemanticsLabel('10,000원 이하 필터 해제'));
      await tester.pump();
      controller.send(_bounds(37.5, 37.6, 126.9, 127.05));
      await tester.pump(const Duration(milliseconds: 350));
      expect(_renderedStoreIds(controller), ['near', 'middle', 'far']);
      semantics.dispose();
      await disposeHome(tester);
    },
  );

  testWidgets('compass bursts are redrawn at most every 100ms', (tester) async {
    final controller = await pumpHome(
      tester,
      const HomeMapScreen(storeLoader: _emptyLoader),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(compass, isNotNull, reason: 'tracking starts after permission');
    controller.scripts.clear();
    for (var i = 0; i < 20; i++) {
      compass!.success(<double>[10.0 + i, 10.0 + i, 1]);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final headings = controller.scripts
        .where((script) => script.startsWith('updateUserHeading('))
        .toList();
    expect(headings, ['updateUserHeading(10.0);', 'updateUserHeading(29.0);']);

    compass!.success(<double>[30.0, 30.0, 1]);
    await tester.pump();
    expect(
      controller.scripts.where(
        (script) => script.startsWith('updateUserHeading('),
      ),
      hasLength(2),
      reason: 'a one-degree change is not redrawn',
    );
    await disposeHome(tester);
  });

  testWidgets('closing home during the permission dialog starts no tracking', (
    tester,
  ) async {
    geolocator.permission = LocationPermission.denied;
    final permissionAnswer = Completer<LocationPermission>();
    geolocator.permissionRequest = permissionAnswer.future;
    await pumpHome(tester, const HomeMapScreen(storeLoader: _emptyLoader));
    await tester.pump(const Duration(milliseconds: 50));
    expect(geolocator.permissionRequests, 1);

    await tester.pumpWidget(const SizedBox());
    permissionAnswer.complete(LocationPermission.whileInUse);
    await tester.pump(const Duration(seconds: 2));
    expect(geolocator.positionStreams, 0);
    expect(compass, isNull);
  });

  testWidgets(
    'a screen covering home stops location tracking until it returns',
    (tester) async {
      await pumpHome(tester, const HomeMapScreen(storeLoader: _emptyLoader));
      await tester.pump(const Duration(milliseconds: 50));
      expect(geolocator.positionStreams, 1);
      expect(compass, isNotNull);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('매장 상세')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        geolocator.positionStreamCancels,
        1,
        reason: 'GPS stops while covered',
      );

      compass = null;
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        geolocator.positionStreams,
        2,
        reason: 'tracking restarts on return',
      );
      expect(compass, isNotNull);
      await disposeHome(tester);
    },
  );

  testWidgets('a GPS timeout falls back to an older fix, or offers a retry', (
    tester,
  ) async {
    geolocator.currentPositionError = TimeoutException('no fix');
    geolocator.lastKnown = _position(
      36.35,
      127.38,
      DateTime.now().subtract(const Duration(hours: 1)),
    );
    final controller = await pumpHome(
      tester,
      const HomeMapScreen(storeLoader: _emptyLoader),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.scripts, contains('setMapCenter(36.35, 127.38);'));
    expect(find.text('현재 위치를 찾지 못했어요'), findsNothing);
    await disposeHome(tester);

    webViews.controllers.clear();
    geolocator.lastKnown = null;
    await pumpHome(tester, const HomeMapScreen(storeLoader: _emptyLoader));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('현재 위치를 찾지 못했어요'), findsOneWidget);
    final attempts = geolocator.currentPositionRequests;
    await tester.tap(find.text('다시 시도'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(geolocator.currentPositionRequests, greaterThan(attempts));
    await disposeHome(tester);
  });

  testWidgets('returning from location settings centers on the user', (
    tester,
  ) async {
    geolocator.serviceEnabled = false;
    final controller = await pumpHome(
      tester,
      const HomeMapScreen(storeLoader: _emptyLoader),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('위치 서비스를 켜주세요'), findsOneWidget);
    await tester.tap(find.text('설정 열기'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(geolocator.locationSettingsOpened, 1);

    geolocator.serviceEnabled = true;
    controller.scripts.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.scripts, contains('setMapCenter(37.5665, 126.978);'));
    await disposeHome(tester);
  });

  testWidgets(
    'the location notice hides the map controls from screen readers',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        geolocator.serviceEnabled = false;
        await pumpHome(tester, const HomeMapScreen(storeLoader: _emptyLoader));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('위치 서비스를 켜주세요'), findsOneWidget);
        expect(find.semantics.byLabel('AI 추천받기'), findsNothing);

        await tester.tap(find.text('나중에 할게요'));
        await tester.pump();
        expect(find.semantics.byLabel('AI 추천받기'), findsOne);
        await disposeHome(tester);
      } finally {
        semantics.dispose();
      }
    },
  );
}

Future<HomeMapStoreLoadResult> _emptyLoader({
  required Map<String, double> bounds,
  required List<Store> cachedStores,
}) async => const HomeMapStoreLoadResult(stores: [], hasFreshResponse: true);

Store _store(
  String id,
  double latitude,
  double longitude, {
  String name = '',
  String menu = '국밥',
}) => Store.fromJson({
  'id': id,
  'storeName': name.isEmpty ? '매장 $id' : name,
  'address': '서울특별시 중구 세종대로',
  'industry': '한식',
  'menu1': menu,
  'price1': '8000',
  'latitude': latitude,
  'longitude': longitude,
});

Position _position(double latitude, double longitude, DateTime timestamp) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

String _bounds(
  double minLat,
  double maxLat,
  double minLng,
  double maxLng, {
  double? centerLat,
  double? centerLng,
  int level = 5,
}) {
  final payload = jsonEncode({
    'minLat': minLat,
    'maxLat': maxLat,
    'minLng': minLng,
    'maxLng': maxLng,
    'centerLat': centerLat ?? (minLat + maxLat) / 2,
    'centerLng': centerLng ?? (minLng + maxLng) / 2,
    'level': level,
  });
  return 'BOUNDS:$payload';
}

String _click(int index, String storeId) {
  final payload = jsonEncode({'index': index, 'storeId': storeId});
  return 'CLICK:$payload';
}

List<String> _renderedStoreIds(_RecordingController controller) {
  final script = controller.scripts.lastWhere(
    (script) => script.startsWith('addMobileMarkers('),
  );
  final literal = script.substring(
    'addMobileMarkers('.length,
    script.length - ');'.length,
  );
  final markers = jsonDecode(jsonDecode(literal) as String) as List;
  return [for (final marker in markers) (marker as Map)['storeId'] as String];
}

class _FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  Future<LocationPermission>? permissionRequest;
  Position? lastKnown = _position(37.5665, 126.978, DateTime.now());
  Object? currentPositionError;
  int permissionRequests = 0;
  int positionStreams = 0;
  int positionStreamCancels = 0;
  int currentPositionRequests = 0;
  int locationSettingsOpened = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() {
    permissionRequests++;
    return permissionRequest ?? Future.value(LocationPermission.whileInUse);
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => lastKnown;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    currentPositionRequests++;
    final error = currentPositionError;
    if (error != null) throw error;
    return _position(37.5665, 126.978, DateTime.now());
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    positionStreams++;
    return StreamController<Position>(
      onCancel: () => positionStreamCancels++,
    ).stream;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }
}

class _RecordingWebViewPlatform extends WebViewPlatform {
  final controllers = <_RecordingController>[];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = _RecordingController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _RecordingNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);
}

class _RecordingController extends PlatformWebViewController {
  _RecordingController(super.params) : super.implementation();

  final scripts = <String>[];
  final htmlLoads = <String>[];
  JavaScriptChannelParams? channel;
  _RecordingNavigationDelegate? navigationDelegate;

  void send(String message) =>
      channel!.onMessageReceived(JavaScriptMessage(message: message));

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    navigationDelegate = handler as _RecordingNavigationDelegate;
  }

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channel = params;
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    htmlLoads.add(html);
  }

  @override
  Future<void> runJavaScript(String javaScript) async {
    scripts.add(javaScript);
  }
}

class _RecordingNavigationDelegate extends PlatformNavigationDelegate {
  _RecordingNavigationDelegate(super.params) : super.implementation();

  WebResourceErrorCallback? onWebResourceError;

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {
    this.onWebResourceError = onWebResourceError;
  }
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox();
}
