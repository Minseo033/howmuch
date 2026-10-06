import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/route_map_point.dart';
import 'package:howmuch/features/recommendation/presentation/widgets/route_map_view.dart';
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
}

class _RecordingWebViewPlatform extends WebViewPlatform {
  final htmlLoads = <String>[];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _RecordingController(params, htmlLoads);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);
}

class _RecordingController extends PlatformWebViewController {
  _RecordingController(super.params, this.htmlLoads) : super.implementation();

  final List<String> htmlLoads;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

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
