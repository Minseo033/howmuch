import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/home_map_store_loader.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WebViewPlatform.instance = _FakeWebViewPlatform();
    HomeMapScreen.globalAllStores = [];
    HomeMapScreen.globalUserPosition = null;
    HomeMapScreen.hasRequestedLocationWeb = true;
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(568, 320),
  ]) {
    testWidgets('home controls stay visible without overflow at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: HomeMapScreen(showAiSpotlight: false)),
      );
      await tester.pump();

      for (final key in const [
        ValueKey('home-search-control'),
        ValueKey('home-today-pick-card'),
        ValueKey('home-location-control'),
        ValueKey('home-ai-control'),
        ValueKey('home-bottom-navigation'),
      ]) {
        final finder = find.byKey(key);
        expect(finder, findsOneWidget);
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'desktop home uses the same centered product shell as other tabs',
    (tester) async {
      const viewport = Size(1280, 800);
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: HomeMapScreen(showAiSpotlight: false)),
      );
      await tester.pump();

      final shellLeft = (viewport.width - FigmaMobileCanvas.maxWebWidth) / 2;
      final shellRight = shellLeft + FigmaMobileCanvas.maxWebWidth;
      for (final key in const [
        ValueKey('home-search-control'),
        ValueKey('home-today-pick-card'),
        ValueKey('home-location-control'),
        ValueKey('home-ai-control'),
        ValueKey('home-bottom-navigation'),
      ]) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.left, greaterThanOrEqualTo(shellLeft));
        expect(rect.right, lessThanOrEqualTo(shellRight));
      }

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('restored home cache is shared with the AI recommendation flow', (
    tester,
  ) async {
    final cachedStore = Store.fromJson({
      'id': 'cached-store',
      'storeName': '캐시 매장',
      'address': '서울시 중구',
      'menu1': '백반',
      'price1': '7000',
      'latitude': 37.56,
      'longitude': 126.98,
    });
    SharedPreferences.setMockInitialValues({
      homeMapStoreCacheKey: encodeHomeMapStoreCache([cachedStore]),
    });

    await tester.pumpWidget(
      const MaterialApp(home: HomeMapScreen(showAiSpotlight: false)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(HomeMapScreen.globalAllStores, hasLength(1));
    expect(HomeMapScreen.globalAllStores.single.id, 'cached-store');
  });
}

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _FakePlatformWebViewController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakePlatformWebViewWidget(params);
}

class _FakePlatformWebViewController extends PlatformWebViewController {
  _FakePlatformWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

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
