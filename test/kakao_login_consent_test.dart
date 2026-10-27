import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_router.dart';
import 'package:howmuch/app/startup_location.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_popup_code.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

OAuthToken _token() => OAuthToken(
  'kakao-access-token',
  DateTime(2030),
  'refresh-token',
  DateTime(2030),
  const [],
);

User _kakaoUserNeedingConsent() => User.fromJson({
  'id': 1,
  'kakao_account': {
    'email_needs_agreement': true,
    'profile_image_needs_agreement': true,
    'profile': {'nickname': '카카오'},
  },
});

User _kakaoUserWith({String? email, String? image}) => User.fromJson({
  'id': 1,
  'kakao_account': {
    'email': ?email,
    'profile': {'nickname': '카카오', 'profile_image_url': ?image},
  },
});

class _FakeConsent implements KakaoConsentRequest {
  _FakeConsent(this._authorize);

  final Future<OAuthToken> Function(List<String> scopes) _authorize;
  final requestedScopes = <List<String>>[];
  var closeCount = 0;

  @override
  Future<OAuthToken> authorize(List<String> scopes) {
    requestedScopes.add(scopes);
    return _authorize(scopes);
  }

  @override
  void close() => closeCount++;
}

GoRouter _testRouter() => GoRouter(
  initialLocation: '/login',
  routes: [
    for (final path in ['/login', '/home', '/profile-setup', '/splash'])
      GoRoute(path: path, builder: (_, _) => const SizedBox()),
  ],
);

/// Fake backend for /api/auth/kakao and /api/user/profile.
MockClient _backend({
  required Map<String, dynamic>? storedProfile,
  required List<Map<String, dynamic>> savedProfiles,
}) => MockClient((request) async {
  if (request.url.path == '/api/auth/kakao') {
    return http.Response(
      jsonEncode({'firebaseUid': 'kakao:1', 'sessionToken': 'session-1'}),
      200,
    );
  }
  if (request.url.path == '/api/user/profile' && request.method == 'GET') {
    return storedProfile == null
        ? http.Response('', 404)
        : http.Response.bytes(utf8.encode(jsonEncode(storedProfile)), 200);
  }
  if (request.url.path == '/api/user/profile' && request.method == 'POST') {
    savedProfiles.add(jsonDecode(request.body) as Map<String, dynamic>);
    return http.Response('{}', 200);
  }
  return http.Response('unexpected', 500);
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await ApiClient.setSessionToken(null);
  });

  ProviderContainer containerWith(
    KakaoLoginService Function(Ref ref) create, {
    GoRouter? router,
  }) {
    final container = ProviderContainer(
      overrides: [
        appRouterProvider.overrideWithValue(router ?? _testRouter()),
        kakaoLoginServiceProvider.overrideWith(create),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('login never asks Kakao for additional consent', () async {
    var consentRequests = 0;
    final router = _testRouter();
    final saved = <Map<String, dynamic>>[];
    final container = containerWith(
      (ref) => KakaoLoginService(
        ref,
        talkInstalled: () async => false,
        accountLogin: () async => _token(),
        loadKakaoUser: () async => _kakaoUserNeedingConsent(),
        beginConsent: () {
          consentRequests++;
          return _FakeConsent((_) async => _token());
        },
      ),
      router: router,
    );

    final result = await http.runWithClient(
      () => container.read(kakaoLoginServiceProvider).login(),
      () => _backend(
        storedProfile: {
          'nickname': '절약왕',
          'email': 'saver@example.com',
          'region': '서울 마포구',
          'favoriteCategories': ['한식'],
          'nicknamePublic': false,
          'activityPublic': false,
        },
        savedProfiles: saved,
      ),
    );

    expect(result.status, KakaoLoginStatus.success);
    expect(consentRequests, 0, reason: 'login must not open a consent window');
    expect(router.routeInformationProvider.value.uri.path, '/home');
    final profile = container.read(userProfileProvider);
    expect(profile.nickname, '절약왕');
    expect(
      profile.nicknamePublic,
      isFalse,
      reason: 'the stored visibility choice must reach the profile screen',
    );
    expect(saved, isEmpty, reason: 'nothing new from Kakao means no re-save');
  });

  test('login opens the address requested before login, once', () async {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        for (final path in ['/login', '/home', '/mypage'])
          GoRoute(path: path, builder: (_, _) => const SizedBox()),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        appRouterProvider.overrideWithValue(router),
        startupLocationProvider.overrideWithValue(StartupLocation('/mypage')),
        kakaoLoginServiceProvider.overrideWith(
          (ref) => KakaoLoginService(
            ref,
            talkInstalled: () async => false,
            accountLogin: () async => _token(),
            loadKakaoUser: () async =>
                _kakaoUserWith(email: 'saver@example.com'),
            beginConsent: () => _FakeConsent((_) async => _token()),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await http.runWithClient(
      () => container.read(kakaoLoginServiceProvider).login(),
      () => _backend(
        storedProfile: {'nickname': '절약왕', 'email': 'saver@example.com'},
        savedProfiles: [],
      ),
    );

    expect(result.status, KakaoLoginStatus.success);
    expect(router.routeInformationProvider.value.uri.path, '/mypage');
    expect(container.read(startupLocationProvider).take(), '/home');
  });

  test('login saves only what Kakao adds and keeps visibility flags', () async {
    final saved = <Map<String, dynamic>>[];
    final container = containerWith(
      (ref) => KakaoLoginService(
        ref,
        talkInstalled: () async => false,
        accountLogin: () async => _token(),
        loadKakaoUser: () async =>
            _kakaoUserWith(image: 'https://k.kakaocdn.net/new.jpg'),
        beginConsent: () => _FakeConsent((_) async => _token()),
      ),
    );

    final result = await http.runWithClient(
      () => container.read(kakaoLoginServiceProvider).login(),
      () => _backend(
        storedProfile: {
          'nickname': '절약왕',
          'email': 'saver@example.com',
          'region': '서울 마포구',
          'favoriteCategories': ['한식'],
          'profileImageUrl': 'https://k.kakaocdn.net/old.jpg',
          'nicknamePublic': false,
        },
        savedProfiles: saved,
      ),
    );

    expect(result.status, KakaoLoginStatus.success);
    expect(saved, hasLength(1));
    expect(saved.single['profileImageUrl'], 'https://k.kakaocdn.net/new.jpg');
    expect(saved.single['email'], 'saver@example.com');
    expect(saved.single.containsKey('nicknamePublic'), isFalse);
    expect(saved.single.containsKey('activityPublic'), isFalse);
  });

  test(
    'KakaoTalk failure other than cancel falls back to account login',
    () async {
      var accountLogins = 0;
      final container = containerWith(
        (ref) => KakaoLoginService(
          ref,
          talkInstalled: () async => true,
          talkLogin: () async => throw PlatformException(code: 'NOT_LOGGED_IN'),
          accountLogin: () async {
            accountLogins++;
            throw KakaoClientException(ClientErrorCause.cancelled, '취소');
          },
        ),
      );

      final result = await container.read(kakaoLoginServiceProvider).login();

      expect(accountLogins, 1);
      expect(result.status, KakaoLoginStatus.cancelled);
    },
  );

  test('concurrent login taps share one Kakao attempt', () async {
    var oauthCalls = 0;
    final pending = Completer<OAuthToken>();
    final container = containerWith(
      (ref) => KakaoLoginService(
        ref,
        talkInstalled: () async => false,
        accountLogin: () {
          oauthCalls++;
          return pending.future;
        },
      ),
    );
    final service = container.read(kakaoLoginServiceProvider);

    final first = service.login();
    final second = service.login();
    await Future<void>.delayed(Duration.zero);
    pending.completeError(
      KakaoClientException(ClientErrorCause.cancelled, '취소'),
    );

    expect((await first).status, KakaoLoginStatus.cancelled);
    expect((await second).status, KakaoLoginStatus.cancelled);
    expect(oauthCalls, 1);
  });

  group('explicit consent request', () {
    test('opens the consent window before the first await', () async {
      var begun = 0;
      final consent = _FakeConsent((_) async => _token());
      final container = containerWith(
        (ref) => KakaoLoginService(
          ref,
          loadKakaoUser: () async => _kakaoUserWith(),
          beginConsent: () {
            begun++;
            return consent;
          },
        ),
      );

      final pending = container
          .read(kakaoLoginServiceProvider)
          .requestKakaoIdentityConsent();
      expect(begun, 1, reason: 'popup must open inside the tap handler');
      await pending;
    });

    test('an unanswered window times out and is closed', () async {
      final consent = _FakeConsent(
        (_) async => throw TimeoutException('Kakao Login timed out.'),
      );
      final container = containerWith(
        (ref) => KakaoLoginService(
          ref,
          loadKakaoUser: () async => _kakaoUserNeedingConsent(),
          beginConsent: () => consent,
        ),
      );

      final result = await container
          .read(kakaoLoginServiceProvider)
          .requestKakaoIdentityConsent();

      expect(result.outcome, KakaoConsentOutcome.timedOut);
      expect(consent.requestedScopes.single, [
        'account_email',
        'profile_image',
      ]);
      expect(consent.closeCount, 1);
    });

    test('a blocked window is reported instead of waiting', () async {
      final container = containerWith(
        (ref) => KakaoLoginService(
          ref,
          loadKakaoUser: () async => _kakaoUserNeedingConsent(),
          beginConsent: () => _FakeConsent(
            (_) async => throw PlatformException(code: 'POPUP_BLOCKED'),
          ),
        ),
      );

      final result = await container
          .read(kakaoLoginServiceProvider)
          .requestKakaoIdentityConsent();

      expect(result.outcome, KakaoConsentOutcome.blocked);
    });

    test('granted consent reloads the Kakao account', () async {
      var loads = 0;
      final container = containerWith(
        (ref) => KakaoLoginService(
          ref,
          loadKakaoUser: () async => ++loads == 1
              ? _kakaoUserNeedingConsent()
              : _kakaoUserWith(
                  email: 'saver@example.com',
                  image: 'https://k.kakaocdn.net/p.jpg',
                ),
          beginConsent: () => _FakeConsent((_) async => _token()),
        ),
      );

      final result = await container
          .read(kakaoLoginServiceProvider)
          .requestKakaoIdentityConsent();

      expect(result.outcome, KakaoConsentOutcome.granted);
      expect(result.email, 'saver@example.com');
      expect(result.profileImageUrl, 'https://k.kakaocdn.net/p.jpg');
      expect(container.read(userProfileProvider).email, 'saver@example.com');
    });

    test('nothing to consent closes the window without authorizing', () async {
      final consent = _FakeConsent((_) async => _token());
      final container = containerWith(
        (ref) => KakaoLoginService(
          ref,
          loadKakaoUser: () async => _kakaoUserWith(),
          beginConsent: () => consent,
        ),
      );

      final result = await container
          .read(kakaoLoginServiceProvider)
          .requestKakaoIdentityConsent();

      expect(result.outcome, KakaoConsentOutcome.notNeeded);
      expect(consent.requestedScopes, isEmpty);
      expect(consent.closeCount, 1);
    });
  });

  test('popup authorize URL carries consent scope and agt', () {
    final uri = kakaoPopupAuthorizeUri(
      clientId: 'test-js-key',
      state: 'state',
      verifier: 'verifier',
      kaHeader: 'ka',
      host: 'kauth.kakao.com',
      scopes: const ['account_email', 'profile_image'],
      agt: 'agt-token',
    );
    expect(uri.queryParameters['scope'], 'account_email profile_image');
    expect(uri.queryParameters['agt'], 'agt-token');
    expect(uri.queryParameters['is_popup'], 'true');
    expect(kakaoConsentPopupTimeout, const Duration(seconds: 90));
  });

  test('Kakao unlink failure after withdrawal is swallowed', () async {
    final container = containerWith(
      (ref) => KakaoLoginService(
        ref,
        unlinkKakao: () async => throw StateError('network down'),
      ),
    );
    await expectLater(
      container.read(kakaoLoginServiceProvider).unlinkKakaoAfterWithdrawal(),
      completes,
    );
  });
}
