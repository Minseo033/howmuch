import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/todays_pick_screen.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// QA #23: today's pick is chosen by weather and distance. Opening it on the
/// map must not call it an AI recommendation.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WebViewPlatform.instance = _FakeWebViewPlatform();
    _FakePlatformWebViewController.channels.clear();
    HomeMapScreen.globalAllStores = [];
    HomeMapScreen.globalUserPosition = null;
    HomeMapScreen.hasRequestedLocationWeb = true;
  });

  Future<void> openMap(
    WidgetTester tester,
    AiMapRecommendationResult result,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: HomeMapScreen(initialRecommendation: result)),
    );
    await tester.pump();
    _FakePlatformWebViewController.channels['Print']!.onMessageReceived(
      const JavaScriptMessage(message: 'Map Initialized on Mobile'),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets("today's pick is labelled as today's pick on the map", (
    tester,
  ) async {
    final result = buildTodaysPickMapResult([
      _item(_store('pick-1', '착한식당', 37.56)),
      _item(_store('pick-2', '동네카페', 37.561)),
    ]);
    expect(result.origin, MapResultOrigin.todaysPick);

    await openMap(tester, result);

    expect(find.text('오늘의 픽 2곳'), findsOneWidget);
    expect(find.text('오늘의 픽 '), findsOneWidget);
    expect(find.text('AI 추천 매장 2곳'), findsNothing);
    expect(find.text('AI 추천 결과 '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an AI chat result keeps its AI labels', (tester) async {
    final store = _store('ai-1', 'AI 백반집', 37.56);
    await openMap(
      tester,
      AiMapRecommendationResult(storeIds: [store.id], stores: [store]),
    );

    expect(find.text('AI 추천 매장 1곳'), findsOneWidget);
    expect(find.text('AI 추천 결과 '), findsOneWidget);
    expect(find.textContaining('오늘의 픽 1곳'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Store _store(String id, String name, double latitude) => Store.fromJson({
  'storeId': id,
  'storeName': name,
  'address': '서울시 중구',
  'industry': '한식',
  'menu1': '백반',
  'price1': '7000',
  'latitude': latitude,
  'longitude': 126.98,
});

TodaysPickItem _item(Store store) => TodaysPickItem(
  id: store.id,
  storeName: store.storeName,
  menuName: '백반',
  price: '7,000원',
  priceValue: 7000,
  tipText: '',
  distance: '100m',
  badgeText: '착한가격업소',
  badgeColor: Colors.blue,
  badgeBg: Colors.blueAccent,
  tags: const [],
  store: store,
);

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _FakePlatformWebViewController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakePlatformWebViewWidget(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakePlatformNavigationDelegate(params);
}

class _FakePlatformWebViewController extends PlatformWebViewController {
  _FakePlatformWebViewController(super.params) : super.implementation();

  static final channels = <String, JavaScriptChannelParams>{};

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channels[params.name] = params;
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {}
}

class _FakePlatformWebViewWidget extends PlatformWebViewWidget {
  _FakePlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  _FakePlatformNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}
