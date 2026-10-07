import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/app_theme.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/store/presentation/screens/store_detail_screen.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// iOS text sizes relative to the default body size (17pt):
/// accessibility-large is 33pt and the largest accessibility size 53pt.
const _ax2 = 33 / 17;
const _ax5 = 53 / 17;
const _textScales = [1.0, 1.3, _ax2, 2.0, _ax5];

/// iPhone 17 Pro.
const _portrait = Size(402, 874);
const _portraitInsets = EdgeInsets.only(top: 62, bottom: 34);
const _landscape = Size(874, 402);
const _landscapeInsets = EdgeInsets.only(left: 62, right: 62, bottom: 21);

void main() {
  setUpAll(() async {
    // Measure with the font the app ships so widths match the device.
    final font = rootBundle.load('assets/fonts/NotoSansKR-Variable.ttf');
    await (FontLoader('Noto Sans KR')..addFont(font)).load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken(null);
  });

  group('large text (QA 10/7 #5)', () {
    for (final width in [320.0, 375.0, 402.0, 430.0]) {
      for (final scale in _textScales) {
        testWidgets('tab labels fit the bar at $width, text x$scale', (
          tester,
        ) async {
          _setViewport(tester, Size(width, 200));
          await tester.pumpWidget(
            _app(
              scale,
              Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: HowmuchBottomNav.heightFor(34),
                    child: const HowmuchBottomNav(safeBottom: 34),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          for (final label in ['홈', '탐색', '제보', '리포트', '마이']) {
            _expectTextFits(
              tester,
              find.text(label),
              inside: find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(AnimatedContainer),
                  )
                  .first,
            );
          }
        });
      }
    }

    for (final (size, insets, scales) in [
      (_portrait, _portraitInsets, [1.0, _ax2, 2.0, _ax5]),
      // The menu header of the page body needs more than 320 at 3.1x; that
      // size is outside this QA round.
      (const Size(320, 568), const EdgeInsets.only(top: 20), [1.0, _ax2, 2.0]),
    ]) {
      for (final scale in scales) {
        testWidgets('store detail actions fit at $size, text x$scale', (
          tester,
        ) async {
          _setViewport(tester, size, insets: insets);
          await _pumpStoreDetail(tester, scale);

          expect(tester.takeException(), isNull);
          _expectStoreActionsFit(tester, size);
        });
      }
    }

    for (final scale in _textScales) {
      testWidgets('home banner, AI button and tabs fit, text x$scale', (
        tester,
      ) async {
        _setViewport(tester, _portrait, insets: _portraitInsets);
        await _pumpHome(tester, scale);

        expect(tester.takeException(), isNull);
        final card = find.byKey(const ValueKey('home-today-pick-card'));
        _expectTextFits(tester, find.text('오늘의 픽'), inside: card);
        _expectTextFits(tester, find.text('날씨와 거리로 매장 추천'), inside: card);
        _expectTextFits(
          tester,
          _richText('AI 추천받기'),
          inside: find.byKey(const ValueKey('home-ai-control')),
        );
        for (final label in ['홈', '탐색', '제보', '리포트', '마이']) {
          _expectTextFits(tester, find.text(label));
        }
      });
    }

    for (final scale in [1.0, _ax2]) {
      testWidgets('short landscape home keeps its banner, text x$scale', (
        tester,
      ) async {
        _setViewport(tester, const Size(568, 320));
        await _pumpHome(tester, scale);

        expect(tester.takeException(), isNull);
        final card = find.byKey(const ValueKey('home-today-pick-card'));
        expect(card, findsOneWidget);
        _expectTextFits(tester, find.text('날씨와 거리로 매장 추천'), inside: card);
      });
    }

    for (final width in [318.0, 331.0, 360.0, 366.0]) {
      for (final scale in _textScales) {
        testWidgets('map card price stays inside at $width, text x$scale', (
          tester,
        ) async {
          await tester.pumpWidget(
            _app(
              scale,
              Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    height: 158,
                    child: HomeMapStoreSummaryCard(store: _store),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          final card = find.byType(HomeMapStoreSummaryCard);
          _expectTextFits(tester, find.text('3,000원'), inside: card);
          _expectTextFits(tester, find.text('김치찌개'), inside: card);
          _expectTextFits(tester, find.text('상세보기'), inside: card);
        });
      }
    }
  });

  group('landscape (QA 10/7 #44, #45)', () {
    for (final (size, insets) in [
      (_landscape, _landscapeInsets),
      // iPhone 14 Pro and an inset-free small phone.
      (const Size(852, 393), const EdgeInsets.fromLTRB(59, 0, 59, 21)),
      (const Size(568, 320), EdgeInsets.zero),
    ]) {
      for (final scale in [1.0, 1.3, _ax2]) {
        testWidgets('store detail actions fit at $size, text x$scale', (
          tester,
        ) async {
          _setViewport(tester, size, insets: insets);
          await _pumpStoreDetail(tester, scale);

          expect(tester.takeException(), isNull);
          _expectStoreActionsFit(tester, size);
        });
      }
    }

    testWidgets('the home map fills the screen behind the 430 controls', (
      tester,
    ) async {
      _setViewport(tester, _landscape, insets: _landscapeInsets);
      await _pumpHome(tester, 1);

      expect(tester.takeException(), isNull);
      final map = tester.getRect(
        find.byKey(const ValueKey('kakao-map-mobile')),
      );
      expect(map.left, 0);
      expect(map.right, _landscape.width);

      final shellLeft = (_landscape.width - FigmaMobileCanvas.maxWebWidth) / 2;
      final shellRight = shellLeft + FigmaMobileCanvas.maxWebWidth;
      for (final key in const [
        ValueKey('home-search-control'),
        ValueKey('home-today-pick-card'),
        ValueKey('home-location-control'),
        ValueKey('home-ai-control'),
        ValueKey('home-bottom-navigation'),
      ]) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.left, greaterThanOrEqualTo(shellLeft), reason: '$key');
        expect(rect.right, lessThanOrEqualTo(shellRight), reason: '$key');
      }
    });

    testWidgets('a portrait phone keeps the map inside the screen width', (
      tester,
    ) async {
      _setViewport(tester, _portrait, insets: _portraitInsets);
      await _pumpHome(tester, 1);

      final map = tester.getRect(
        find.byKey(const ValueKey('kakao-map-mobile')),
      );
      expect(map.left, 0);
      expect(map.right, _portrait.width);
    });

    test('notch insets outside the centered column are dropped', () {
      const data = MediaQueryData(
        padding: EdgeInsets.fromLTRB(62, 0, 62, 21),
        viewPadding: EdgeInsets.fromLTRB(62, 0, 62, 21),
      );
      final inside = FigmaMobileCanvas.insetsInsideColumn(data, 222);
      expect(inside.padding, const EdgeInsets.only(bottom: 21));
      expect(inside.viewPadding, const EdgeInsets.only(bottom: 21));
      // A column close to the edge keeps the part of the inset it overlaps.
      final near = FigmaMobileCanvas.insetsInsideColumn(data, 30);
      expect(near.padding, const EdgeInsets.fromLTRB(32, 0, 32, 21));
    });

    testWidgets('rotating keeps the screen state inside the canvas', (
      tester,
    ) async {
      _setViewport(tester, _portrait, insets: _portraitInsets);
      EdgeInsets? padding;
      await tester.pumpWidget(
        MaterialApp(
          home: FigmaMobileCanvas(
            child: Builder(
              builder: (context) {
                padding = MediaQuery.paddingOf(context);
                return const TextField(key: ValueKey('draft'));
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const ValueKey('draft')), '초안');
      final state = tester.state(find.byType(EditableText));

      _setViewport(tester, _landscape, insets: _landscapeInsets);
      await tester.pump();

      expect(tester.state(find.byType(EditableText)), same(state));
      expect(find.text('초안'), findsOneWidget);
      expect(padding, const EdgeInsets.only(bottom: 21));
    });
  });
}

final _store = Store.fromJson({
  'id': 'card-store',
  'storeName': '미락칼국수',
  'address': '서울특별시 서대문구 이화여대길 52',
  'industry': '한식',
  'menu1': '김치찌개',
  'price1': '3000',
  'latitude': 37.56,
  'longitude': 126.94,
});

void _setViewport(
  WidgetTester tester,
  Size size, {
  EdgeInsets insets = EdgeInsets.zero,
}) {
  final padding = FakeViewPadding(
    left: insets.left,
    top: insets.top,
    right: insets.right,
    bottom: insets.bottom,
  );
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = padding
    ..viewPadding = padding;
  addTearDown(tester.view.reset);
}

Widget _app(double textScale, Widget home) => MaterialApp(
  theme: AppTheme.light(),
  home: home,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
);

Future<void> _pumpStoreDetail(WidgetTester tester, double textScale) async {
  final store = Store.fromJson({
    'storeName': '24시 옛날집',
    'address': '서울특별시 중구 세종대로 110',
    'industry': '한식',
    'phoneNumber': '02-123-4567',
    'menu1': '김치찌개',
    'price1': '9000',
    'latitude': 37.5665,
    'longitude': 126.978,
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storeReviewProvider.overrideWith((ref) => _LocalReviews())],
      child: _app(textScale, StoreDetailScreen(store: store)),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectStoreActionsFit(WidgetTester tester, Size viewport) {
  for (final label in ['전화', '가격 제보', '방문 인증', '길찾기']) {
    final button = find
        .ancestor(of: find.text(label), matching: find.byType(Container))
        .first;
    _expectTextFits(tester, find.text(label), inside: button);
    final rect = tester.getRect(button);
    expect(rect.left, greaterThanOrEqualTo(0), reason: label);
    expect(rect.right, lessThanOrEqualTo(viewport.width), reason: label);
    expect(rect.bottom, lessThanOrEqualTo(viewport.height), reason: label);
  }
}

Future<void> _pumpHome(WidgetTester tester, double textScale) async {
  WebViewPlatform.instance = _FakeWebViewPlatform();
  HomeMapScreen.globalAllStores = [];
  HomeMapScreen.globalUserPosition = null;
  HomeMapScreen.hasRequestedLocationWeb = true;
  HomeMapScreen.clearSavedMapState();
  await tester.pumpWidget(
    _app(textScale, const HomeMapScreen(showAiSpotlight: false)),
  );
  await tester.pump();
}

Finder _richText(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText() == text,
);

/// The whole text is laid out (no clipped line, no ellipsis) and, when given,
/// drawn inside [inside].
void _expectTextFits(WidgetTester tester, Finder text, {Finder? inside}) {
  expect(text, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final label = paragraph.text.toPlainText();
  expect(paragraph.didExceedMaxLines, isFalse, reason: '"$label" is cut');
  expect(
    paragraph.size.height,
    greaterThanOrEqualTo(
      paragraph.getMaxIntrinsicHeight(paragraph.size.width) - .5,
    ),
    reason: '"$label" is clipped vertically',
  );
  if (inside == null) return;
  final rect = tester.getRect(text);
  final bounds = tester.getRect(inside).inflate(.5);
  expect(
    bounds.contains(rect.topLeft) && bounds.contains(rect.bottomRight),
    isTrue,
    reason: '"$label" $rect is outside $bounds',
  );
}

class _LocalReviews extends StoreReviewNotifier {
  @override
  Future<void> loadReviews(String storeId, {bool force = false}) async {}
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

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakePlatformNavigationDelegate(params);
}

class _FakePlatformWebViewController extends PlatformWebViewController {
  _FakePlatformWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {}
}

class _FakePlatformWebViewWidget extends PlatformWebViewWidget {
  _FakePlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  _FakePlatformNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}
