import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/screens/login_screen.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/auth/presentation/state/login_flow.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class _FakeLoginService extends KakaoLoginService {
  _FakeLoginService(super.ref);

  @override
  Future<KakaoLoginResult> login({bool navigate = true}) async {
    await ApiClient.setSessionToken('ai-gate-session');
    return const KakaoLoginResult(KakaoLoginStatus.success);
  }
}

/// The map keeps animating, so frames are pumped for a while instead of
/// waiting for it to settle.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      authTermsAcceptedPreferenceKey: true,
    });
    await ApiClient.setSessionToken(null);
    WebViewPlatform.instance = _FakeWebViewPlatform();
    HomeMapScreen.globalAllStores = [];
    HomeMapScreen.globalUserPosition = null;
    HomeMapScreen.hasRequestedLocationWeb = true;
    HomeMapScreen.clearSavedMapState();
  });
  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets('AI asks a guest to log in before the chat opens', (
    tester,
  ) async {
    const message = 'AI 추천은 로그인 후 이용할 수 있어요.';
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const HomeMapScreen(showAiSpotlight: false),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, state) => LoginScreen(entry: loginEntryOf(state.extra)),
        ),
        GoRoute(
          path: AppRoutes.aiRecommend,
          builder: (_, _) => const Scaffold(body: Text('AI 추천 채팅')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          kakaoLoginServiceProvider.overrideWith(_FakeLoginService.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    final ai = find.byKey(const ValueKey('home-ai-control'));

    await tester.tap(ai);
    await _pumpFrames(tester);
    expect(find.text(message), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await _pumpFrames(tester);
    expect(find.text('AI 추천 채팅'), findsNothing);
    expect(find.byType(HomeMapScreen), findsOneWidget);

    await tester.tap(ai);
    await _pumpFrames(tester);
    expect(find.text(message), findsOneWidget);
    await tester.tap(find.byKey(const Key('login_required_confirm')));
    await _pumpFrames(tester);
    await tester.tap(find.text('카카오로 계속하기'));
    await _pumpFrames(tester);
    expect(find.text('AI 추천 채팅'), findsOneWidget);
  });

  test('a 401 answer asks to log in instead of showing local picks', () async {
    await http.runWithClient(() async {
      final reply = await AiChatService().getGeminiResponse(
        '점심 추천해줘',
        latitude: 37.5,
        longitude: 127,
      );
      expect(reply.text, contains('로그인'));
      expect(isAiUnavailableResponse(reply.text), isFalse);
    }, () => MockClient((_) async => http.Response('{"success":false}', 401)));
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
  Widget build(BuildContext context) => const SizedBox();
}

class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  _FakePlatformNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}
