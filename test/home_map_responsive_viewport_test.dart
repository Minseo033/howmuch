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

  for (final height in [213.0, 260.0, 280.0, 288.0]) {
    testWidgets('short home viewport $height does not invert button bounds', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        tester.view.physicalSize = Size(393, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: HomeMapScreen(showAiSpotlight: false)),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final location = tester.getRect(
          find.byKey(const ValueKey('home-location-control')),
        );
        final ai = tester.getRect(
          find.byKey(const ValueKey('home-ai-control')),
        );
        final navigation = tester.getRect(
          find.byKey(const ValueKey('home-bottom-navigation')),
        );
        for (final rect in [location, ai]) {
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(navigation.top));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(393));
        }
        expect(location.overlaps(ai), isFalse);
        expect(
          tester.getSemantics(find.bySemanticsLabel('AI 추천받기')),
          matchesSemantics(
            label: 'AI 추천받기',
            isButton: true,
            hasTapAction: true,
          ),
        );
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('short home viewport also respects native safe insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 260);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = FakeViewPadding(top: 48, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      const MaterialApp(home: HomeMapScreen(showAiSpotlight: false)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final navigation = tester.getRect(
      find.byKey(const ValueKey('home-bottom-navigation')),
    );
    for (final key in const [
      ValueKey('home-location-control'),
      ValueKey('home-ai-control'),
    ]) {
      final rect = tester.getRect(find.byKey(key));
      expect(rect.top, greaterThanOrEqualTo(48));
      expect(rect.bottom, lessThanOrEqualTo(navigation.top));
    }
  });

  testWidgets('home survives 20 short and normal viewport transitions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(393, 800);
    await tester.pumpWidget(
      const MaterialApp(home: HomeMapScreen(showAiSpotlight: false)),
    );
    for (var index = 0; index < 20; index++) {
      tester.view.physicalSize = Size(393, index.isEven ? 213 : 800);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'transition $index');
      expect(find.byKey(const ValueKey('home-ai-control')), findsOneWidget);
    }
  });

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
