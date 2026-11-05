import 'dart:async';
import 'dart:convert';
import 'package:howmuch/core/constants/kakao_map_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/route_map_point.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/route_map_view.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/route_map_view_mobile.dart'
    show routeMapReadyChannel, routeMapReadyFallback;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  late _RecordingWebViewPlatform webViews;

  setUp(() {
    webViews = _RecordingWebViewPlatform();
    WebViewPlatform.instance = webViews;
  });

  testWidgets('the route map reloads only when the route changes', (
    tester,
  ) async {
    List<RouteMapPoint> route(double firstLatitude) => [
      RouteMapPoint(
        order: 1,
        name: '첫 매장',
        latitude: firstLatitude,
        longitude: 126.978,
      ),
      const RouteMapPoint(
        order: 2,
        name: '둘째 매장',
        latitude: 37.57,
        longitude: 126.98,
      ),
    ];
    Widget map(List<RouteMapPoint> points, {double? userLatitude}) =>
        MaterialApp(
          home: SizedBox(
            width: 320,
            height: 240,
            child: RouteMapView(
              points: points,
              userLatitude: userLatitude,
              userLongitude: userLatitude == null ? null : 126.97,
            ),
          ),
        );

    await tester.pumpWidget(map(route(37.5665)));
    expect(webViews.htmlLoads, hasLength(1));

    for (var rebuild = 0; rebuild < 5; rebuild++) {
      await tester.pumpWidget(map(route(37.5665)));
    }
    expect(
      webViews.htmlLoads,
      hasLength(1),
      reason: 'the same stops in a new list do not reload the page',
    );

    await tester.pumpWidget(map(route(37.57)));
    expect(webViews.htmlLoads, hasLength(2));

    await tester.pumpWidget(map(route(37.57), userLatitude: 37.56));
    expect(
      webViews.htmlLoads,
      hasLength(3),
      reason: 'a new start point is drawn',
    );
  });

  testWidgets('a loading indicator covers the map until it is drawn (QA #26)', (
    tester,
  ) async {
    Widget map(double firstLatitude) => MaterialApp(
      home: SizedBox(
        width: 320,
        height: 240,
        child: RouteMapView(
          points: [
            RouteMapPoint(
              order: 1,
              name: '첫 매장',
              latitude: firstLatitude,
              longitude: 126.978,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(map(37.5665));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      webViews.htmlLoads.single,
      contains("sendMapMessage('ready')"),
      reason: 'the page reports back when the map is drawn or fails',
    );

    webViews.channels[routeMapReadyChannel]!.onMessageReceived(
      const JavaScriptMessage(message: 'ready'),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    webViews.channels[routeMapReadyChannel]!.onMessageReceived(
      JavaScriptMessage(
        message: jsonEncode({
          'token': RegExp(
            r'const mapBridgeToken = "([a-f0-9]+)"',
          ).firstMatch(webViews.htmlLoads.single)!.group(1),
          'origin': kakaoMapAuthorizedOrigin,
          'message': 'ready',
        }),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(map(37.57));
    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason: 'a new route is loading again',
    );
  });

  testWidgets(
    'old navigation and page finish cannot consume a newer route bootstrap',
    (tester) async {
      Widget route(double lat) => MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: RouteMapView(
            points: [
              RouteMapPoint(
                order: 1,
                name: 'route',
                latitude: lat,
                longitude: 127,
              ),
            ],
          ),
        ),
      );
      String message(String html) => jsonEncode({
        'token': RegExp(
          r'const mapBridgeToken = "([a-f0-9]+)"',
        ).firstMatch(html)!.group(1),
        'origin': kakaoMapAuthorizedOrigin,
        'message': 'ready',
      });
      await tester.pumpWidget(route(37.5));
      final delegate = webViews.delegates.single;
      final oldFinish = delegate.onPageFinished;
      final oldNavigation = delegate.onNavigationRequest!;
      final oldReady = message(webViews.htmlLoads.single);
      await tester.pumpWidget(route(37.6));
      final currentDelegate = webViews.delegates.last;
      expect(currentDelegate, isNot(same(delegate)));
      // Models WK's delayed A didFinish dispatch after B has begun loading.
      oldFinish?.call(kakaoMapAuthorizedOrigin);
      // A's getUrl Future completes only after B begins. It must not consume B.
      expect(
        await oldNavigation(
          const NavigationRequest(
            url: kakaoMapAuthorizedOrigin,
            isMainFrame: true,
          ),
        ),
        NavigationDecision.prevent,
      );
      webViews.channels[routeMapReadyChannel]!.onMessageReceived(
        JavaScriptMessage(message: oldReady),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        await currentDelegate.onNavigationRequest!(
          const NavigationRequest(
            url: kakaoMapAuthorizedOrigin,
            isMainFrame: true,
          ),
        ),
        NavigationDecision.navigate,
      );
      webViews.channels[routeMapReadyChannel]!.onMessageReceived(
        JavaScriptMessage(message: message(webViews.htmlLoads.last)),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        await currentDelegate.onNavigationRequest!(
          const NavigationRequest(
            url: kakaoMapAuthorizedOrigin,
            isMainFrame: true,
          ),
        ),
        NavigationDecision.prevent,
      );
    },
  );

  testWidgets(
    'superseded pending delegate install never loads an old document',
    (tester) async {
      final installed = Completer<void>();
      webViews.installationGate = installed.future;
      Widget route(double lat) => MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: RouteMapView(
            points: [
              RouteMapPoint(
                order: 1,
                name: 'route',
                latitude: lat,
                longitude: 127,
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(route(37.5));
      expect(webViews.htmlLoads, isEmpty);
      await tester.pumpWidget(route(37.6));
      installed.complete();
      await tester.pump();
      expect(webViews.htmlLoads, hasLength(1));
      expect(webViews.htmlLoads.single, contains('"latitude":37.6'));
      expect(webViews.delegates, hasLength(2));
      expect(
        await webViews.delegates.first.onNavigationRequest!(
          const NavigationRequest(
            url: kakaoMapAuthorizedOrigin,
            isMainFrame: true,
          ),
        ),
        NavigationDecision.prevent,
      );
      expect(
        await webViews.delegates.last.onNavigationRequest!(
          const NavigationRequest(
            url: kakaoMapAuthorizedOrigin,
            isMainFrame: true,
          ),
        ),
        NavigationDecision.navigate,
      );
    },
  );

  testWidgets('the loading indicator does not stay if the page never reports', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: RouteMapView(
            points: [
              RouteMapPoint(
                order: 1,
                name: '첫 매장',
                latitude: 37.5665,
                longitude: 126.978,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(routeMapReadyFallback);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

class _RecordingWebViewPlatform extends WebViewPlatform {
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    final delegate = _RecordingNavigationDelegate(params);
    delegates.add(delegate);
    return delegate;
  }

  final delegates = <_RecordingNavigationDelegate>[];

  Future<void>? installationGate;
  final htmlLoads = <String>[];
  final channels = <String, JavaScriptChannelParams>{};

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) =>
      _RecordingController(params, htmlLoads, channels, () => installationGate);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);
}

class _RecordingController extends PlatformWebViewController {
  _RecordingController(
    super.params,
    this.htmlLoads,
    this.channels,
    this.installationGate,
  ) : super.implementation();

  final Future<void>? Function() installationGate;
  final List<String> htmlLoads;
  final Map<String, JavaScriptChannelParams> channels;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}
  @override
  Future<String?> currentUrl() async => kakaoMapAuthorizedOrigin;
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    final gate = installationGate();
    if (gate != null) await gate;
  }

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channels[params.name] = params;
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    htmlLoads.add(html);
  }
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _RecordingNavigationDelegate extends PlatformNavigationDelegate {
  _RecordingNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageFinished;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    onNavigationRequest = callback;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    onPageFinished = callback;
  }
}
