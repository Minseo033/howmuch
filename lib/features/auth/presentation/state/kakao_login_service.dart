import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';
import 'kakao_account_login_stub.dart'
    if (dart.library.js_interop) 'kakao_account_login_web.dart'
    as account;
import 'kakao_popup_code.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/app/app_router.dart';
import 'package:howmuch/app/startup_location.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/state/user_profile_api_service.dart';
import 'package:howmuch/features/system/presentation/state/push_notification_service.dart';

final kakaoLoginServiceProvider = Provider((ref) => KakaoLoginService(ref));

enum KakaoLoginStatus { success, cancelled, failed }

class KakaoLoginResult {
  const KakaoLoginResult(this.status, [this.errorMessage]) : isNewUser = false;

  /// Kakao login worked but this account has no profile here yet, so sign-up
  /// continues with profile setup.
  const KakaoLoginResult.newUser()
    : status = KakaoLoginStatus.success,
      errorMessage = null,
      isNewUser = true;

  final KakaoLoginStatus status;
  final String? errorMessage;
  final bool isNewUser;
}

/// Outcome of the explicit "카카오 계정 정보 불러오기" consent request.
enum KakaoConsentOutcome {
  /// Kakao reported nothing that additional consent could provide.
  notNeeded,
  granted,
  cancelled,

  /// The browser refused to open the consent window.
  blocked,

  /// The consent window stayed unanswered past [kakaoConsentPopupTimeout].
  timedOut,
  failed,
}

class KakaoIdentityConsentResult {
  const KakaoIdentityConsentResult({
    required this.email,
    required this.profileImageUrl,
    required this.outcome,
  });

  final String email;
  final String profileImageUrl;
  final KakaoConsentOutcome outcome;
}

typedef _KakaoIdentity = ({
  String email,
  String profileImageUrl,
  KakaoConsentOutcome outcome,
});

bool isKakaoLoginCancellation(Object error) =>
    (error is KakaoClientException &&
        error.reason == ClientErrorCause.cancelled) ||
    (error is KakaoAuthException &&
        error.error == AuthErrorCause.accessDenied) ||
    (error is PlatformException && error.code == 'CANCELED');

bool _isPopupBlocked(Object error) =>
    error is PlatformException && error.code == 'POPUP_BLOCKED';

class KakaoLoginService {
  final Ref _ref;

  KakaoLoginService(
    this._ref, {
    Future<bool> Function()? talkInstalled,
    Future<OAuthToken> Function()? talkLogin,
    Future<OAuthToken> Function()? accountLogin,
    KakaoConsentRequest Function()? beginConsent,
    Future<User> Function()? loadKakaoUser,
    Future<void> Function()? unlinkKakao,
  }) : _talkInstalled = talkInstalled ?? isKakaoTalkInstalled,
       _talkLogin = talkLogin ?? (() => UserApi.instance.loginWithKakaoTalk()),
       _accountLogin = accountLogin ?? account.loginWithKakaoAccount,
       _beginConsent = beginConsent ?? account.beginKakaoConsentRequest,
       _loadKakaoUser = loadKakaoUser ?? (() => UserApi.instance.me()),
       _unlinkKakao = unlinkKakao ?? (() => UserApi.instance.unlink());

  final Future<bool> Function() _talkInstalled;
  final Future<OAuthToken> Function() _talkLogin;
  final Future<OAuthToken> Function() _accountLogin;
  final KakaoConsentRequest Function() _beginConsent;
  final Future<User> Function() _loadKakaoUser;
  final Future<void> Function() _unlinkKakao;

  Future<KakaoLoginResult>? _loginInFlight;

  /// Repeated taps (login screen, session-expired screen) share one attempt so
  /// a second Kakao window or backend session never starts concurrently.
  ///
  /// With [navigate] the service also moves on afterwards: to the address
  /// requested before login (otherwise home) for a member, to profile setup
  /// for a new account, and back to the login screen after a failure. A login
  /// opened on top of another screen passes false and returns to that screen
  /// itself. When two screens share an attempt, the one that asked last
  /// decides.
  Future<KakaoLoginResult> login({bool navigate = true}) {
    _navigateAfterLogin = navigate;
    final inFlight = _loginInFlight;
    if (inFlight != null) return inFlight;
    final attempt = _login();
    _loginInFlight = attempt;
    void release() {
      if (identical(_loginInFlight, attempt)) _loginInFlight = null;
    }

    attempt.then((_) => release(), onError: (Object _) => release());
    return attempt;
  }

  bool _navigateAfterLogin = true;

  Future<KakaoLoginResult> _login() async {
    var backendSessionEstablished = false;
    try {
      OAuthToken token;
      if (await _talkInstalled()) {
        try {
          token = await _talkLogin();
          debugPrint('카카오톡으로 로그인 성공');
        } catch (error) {
          if (isKakaoLoginCancellation(error)) {
            return const KakaoLoginResult(KakaoLoginStatus.cancelled);
          }
          // KakaoTalk can be installed yet logged out or unable to return a
          // token. Kakao's documented fallback is the account login.
          debugPrint('카카오톡으로 로그인하지 못해 카카오계정 로그인으로 전환합니다.');
          final accountToken = await _loginWithAccount();
          if (accountToken == null) {
            return const KakaoLoginResult(KakaoLoginStatus.cancelled);
          }
          token = accountToken;
        }
      } else {
        final accountToken = await _loginWithAccount();
        if (accountToken == null) {
          return const KakaoLoginResult(KakaoLoginStatus.cancelled);
        }
        token = accountToken;
      }

      final session = await _authenticateWithBackend(token.accessToken);
      if (session == null) {
        if (_navigateAfterLogin) {
          _ref.read(appRouterProvider).go(AppRoutes.login);
        }
        return const KakaoLoginResult(KakaoLoginStatus.failed, '백엔드 인증 실패');
      }
      backendSessionEstablished = true;
      // Login never asks for additional Kakao consent. On web that opened an
      // unrequested window and the SDK polled for up to 10 minutes; natively it
      // re-prompted on every login. Missing email/photo consent is requested
      // only from the connected-accounts screen.
      final identity = await _loadKakaoIdentity();
      final email = usableAccountEmail(identity.email) ?? session.email;
      final profileImageUrl = identity.profileImageUrl.isNotEmpty
          ? identity.profileImageUrl
          : session.profileImageUrl;
      await _cacheKakaoIdentity(email, profileImageUrl);
      // 백엔드가 발급한 공식 uid/세션 토큰을 사용합니다.
      final firebaseUid = session.uid;

      // 💡 인증 상태 업데이트 (firebaseUid + 세션 토큰 포함)
      _ref
          .read(authStateProvider.notifier)
          .update(
            (state) => state.copyWith(
              isLoggedIn: true,
              provider: '카카오',
              email: email,
              firebaseUid: firebaseUid,
              sessionToken: session.sessionToken,
              profileImageUrl: profileImageUrl,
            ),
          );

      // 💡 프로필 존재 여부에 따라 라우팅 분기
      final profileService = _ref.read(userProfileApiServiceProvider);
      // Only a 404 means that profile setup is required. A temporary server
      // or network failure must never be mistaken for a new account.
      final profile = await profileService.fetchProfile(strict: true);

      if (profile != null) {
        // 기존 사용자: 프로필 데이터로 상태 업데이트 후 홈으로 이동
        final rawCategories = profile['favoriteCategories'];
        final parsedCategories = rawCategories is List
            ? rawCategories.map((e) => e.toString()).toList()
            : null;
        final storedEmail = usableAccountEmail(profile['email']);
        final nicknamePublic = profile['nicknamePublic'];
        final activityPublic = profile['activityPublic'];
        _ref
            .read(userProfileProvider.notifier)
            .update(
              (state) => state.copyWith(
                nickname: profile['nickname'] as String? ?? state.nickname,
                email: storedEmail ?? email,
                region: profile['region'] as String? ?? state.region,
                favoriteCategories:
                    parsedCategories ?? state.favoriteCategories,
                nicknamePublic: nicknamePublic is bool ? nicknamePublic : null,
                activityPublic: activityPublic is bool ? activityPublic : null,
                profileImageUrl: profileImageUrl,
              ),
            );
        // Save only what Kakao adds to the stored profile. Re-saving every
        // field on each login rewrote unchanged data. Visibility flags are
        // omitted so the server keeps the stored choice.
        final addsEmail =
            storedEmail == null && usableAccountEmail(email) != null;
        final changesImage =
            profileImageUrl.isNotEmpty &&
            profileImageUrl !=
                usableProfileImageUrl(profile['profileImageUrl']);
        if (addsEmail || changesImage) {
          await profileService.saveProfile(
            nickname: profile['nickname'] as String? ?? '',
            email: storedEmail ?? email,
            region: profile['region'] as String? ?? '',
            favoriteCategories: parsedCategories ?? const [],
            profileImageUrl: profileImageUrl,
          );
        }
        // The address requested before login, otherwise home.
        if (_navigateAfterLogin) {
          _ref
              .read(appRouterProvider)
              .go(_ref.read(startupLocationProvider).take());
        }
      } else {
        // 신규 사용자: 프로필 설정 화면으로 이동
        _ref
            .read(userProfileProvider.notifier)
            .update(
              (state) => state.copyWith(
                email: email,
                profileImageUrl: profileImageUrl,
              ),
            );
        if (_navigateAfterLogin) {
          _ref.read(appRouterProvider).go(AppRoutes.profileSetup);
        }
        return const KakaoLoginResult.newUser();
      }

      return const KakaoLoginResult(KakaoLoginStatus.success);
    } catch (_) {
      debugPrint('카카오 로그인 처리 중 오류가 발생했습니다.');
      if (backendSessionEstablished) {
        await clearLocalSession(unregisterDevice: false);
      }
      if (_navigateAfterLogin) _ref.read(appRouterProvider).go(AppRoutes.login);
      return const KakaoLoginResult(
        KakaoLoginStatus.failed,
        '로그인 중 통신 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      );
    }
  }

  /// Returns null when the user cancels the Kakao account login.
  Future<OAuthToken?> _loginWithAccount() async {
    try {
      final token = await _accountLogin();
      debugPrint('카카오계정으로 로그인 성공');
      return token;
    } catch (error) {
      if (isKakaoLoginCancellation(error)) return null;
      rethrow;
    }
  }

  /// Reads the latest Kakao email/photo without asking for new consent unless
  /// [requestConsent] is set by an explicit user action.
  Future<({String email, String profileImageUrl})> refreshKakaoIdentity({
    bool requestConsent = false,
  }) async {
    final identity = await _loadKakaoIdentity(requestConsent: requestConsent);
    _applyIdentity(identity);
    return (email: identity.email, profileImageUrl: identity.profileImageUrl);
  }

  /// Explicit consent request from the connected-accounts button. Call it
  /// directly from the tap handler: on web the consent window opens before the
  /// first await so the browser treats it as user initiated.
  Future<KakaoIdentityConsentResult> requestKakaoIdentityConsent() async {
    final identity = await _loadKakaoIdentity(requestConsent: true);
    _applyIdentity(identity);
    return KakaoIdentityConsentResult(
      email: identity.email,
      profileImageUrl: identity.profileImageUrl,
      outcome: identity.outcome,
    );
  }

  void _applyIdentity(_KakaoIdentity identity) {
    final before = _ref.read(userProfileProvider);
    _ref
        .read(authStateProvider.notifier)
        .update(
          (state) => state.copyWith(
            email: identity.email.isNotEmpty ? identity.email : state.email,
            profileImageUrl: identity.profileImageUrl.isNotEmpty
                ? identity.profileImageUrl
                : state.profileImageUrl,
          ),
        );
    _ref
        .read(userProfileProvider.notifier)
        .update(
          (state) => state.copyWith(
            email: identity.email.isNotEmpty ? identity.email : state.email,
            profileImageUrl: identity.profileImageUrl.isNotEmpty
                ? identity.profileImageUrl
                : state.profileImageUrl,
          ),
        );
    _syncIdentityToProfile(before, identity);
  }

  /// Saves only a newly available email or a changed photo. Visibility flags
  /// are omitted so the server keeps the stored choice instead of the local
  /// default.
  void _syncIdentityToProfile(UserProfile before, _KakaoIdentity identity) {
    if (!ApiClient.isAuthenticated) return;
    if (before.nickname.isEmpty || before.nickname == '게스트') return;
    final validEmail = usableAccountEmail(identity.email);
    final emailChanged =
        validEmail != null && validEmail != usableAccountEmail(before.email);
    final imageChanged =
        identity.profileImageUrl.isNotEmpty &&
        identity.profileImageUrl != before.profileImageUrl;
    if (!emailChanged && !imageChanged) return;
    unawaited(
      _ref
          .read(userProfileApiServiceProvider)
          .saveProfile(
            nickname: before.nickname,
            email: validEmail ?? usableAccountEmail(before.email) ?? '',
            region: before.region,
            favoriteCategories: before.favoriteCategories,
            profileImageUrl: imageChanged
                ? identity.profileImageUrl
                : before.profileImageUrl,
          ),
    );
  }

  Future<_KakaoIdentity> _loadKakaoIdentity({
    bool requestConsent = false,
  }) async {
    // Created before the first await: on web this opens the consent window
    // while the user's tap still counts as the popup gesture.
    final consent = requestConsent ? _beginConsent() : null;
    var outcome = KakaoConsentOutcome.notNeeded;
    try {
      final prefs = await SharedPreferences.getInstance();
      var email =
          usableAccountEmail(prefs.getString(kakaoEmailPreferenceKey)) ?? '';
      var profileImageUrl = usableProfileImageUrl(
        prefs.getString(kakaoProfileImagePreferenceKey),
      );

      try {
        var user = await _loadKakaoUser();
        var kakaoAccount = user.kakaoAccount;
        var profile = kakaoAccount?.profile;
        if (consent != null) {
          final scopes = missingKakaoIdentityScopes(
            emailMissing: usableAccountEmail(kakaoAccount?.email) == null,
            emailNeedsAgreement: kakaoAccount?.emailNeedsAgreement == true,
            profileImageMissing: usableProfileImageUrl(
              profile?.profileImageUrl ?? profile?.thumbnailImageUrl,
            ).isEmpty,
            profileImageNeedsAgreement:
                kakaoAccount?.profileImageNeedsAgreement == true,
            legacyProfileNeedsAgreement:
                kakaoAccount?.profileNeedsAgreement == true,
          );
          if (scopes.isNotEmpty) {
            outcome = await _requestConsent(consent, scopes);
            if (outcome == KakaoConsentOutcome.granted) {
              user = await _loadKakaoUser();
              kakaoAccount = user.kakaoAccount;
              profile = kakaoAccount?.profile;
            }
          }
        }

        email = usableAccountEmail(kakaoAccount?.email) ?? email;
        final latestProfileImageUrl = usableProfileImageUrl(
          profile?.profileImageUrl ?? profile?.thumbnailImageUrl,
        );
        if (latestProfileImageUrl.isNotEmpty) {
          profileImageUrl = latestProfileImageUrl;
        }
      } catch (error) {
        debugPrint('카카오 계정 정보 갱신 실패: $error');
        if (consent != null && outcome == KakaoConsentOutcome.notNeeded) {
          outcome = KakaoConsentOutcome.failed;
        }
      }

      if (email.isNotEmpty) {
        await prefs.setString(kakaoEmailPreferenceKey, email);
      }
      if (profileImageUrl.isNotEmpty) {
        await prefs.setString(kakaoProfileImagePreferenceKey, profileImageUrl);
      }
      return (email: email, profileImageUrl: profileImageUrl, outcome: outcome);
    } finally {
      consent?.close();
    }
  }

  Future<KakaoConsentOutcome> _requestConsent(
    KakaoConsentRequest consent,
    List<String> scopes,
  ) async {
    try {
      await consent.authorize(scopes);
      return KakaoConsentOutcome.granted;
    } on TimeoutException {
      return KakaoConsentOutcome.timedOut;
    } catch (error) {
      if (isKakaoLoginCancellation(error)) return KakaoConsentOutcome.cancelled;
      if (_isPopupBlocked(error)) return KakaoConsentOutcome.blocked;
      debugPrint('카카오 계정 정보 추가 동의를 완료하지 못했습니다: $error');
      return KakaoConsentOutcome.failed;
    }
  }

  Future<void> _cacheKakaoIdentity(String email, String profileImageUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (email.isNotEmpty) {
      await prefs.setString(kakaoEmailPreferenceKey, email);
    }
    if (profileImageUrl.isNotEmpty) {
      await prefs.setString(kakaoProfileImagePreferenceKey, profileImageUrl);
    }
  }

  Future<
    ({String uid, String sessionToken, String email, String profileImageUrl})?
  >
  _authenticateWithBackend(String accessToken) async {
    final url = ApiClient.uri('/api/auth/kakao');

    try {
      final response = await http
          .post(
            url,
            headers: ApiClient.jsonHeaders(),
            body: jsonEncode({'kakaoAccessToken': accessToken}),
          )
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        final data = ApiClient.decodeJson(response) as Map<String, dynamic>;
        final uid = data['firebaseUid'] as String?;
        final sessionToken = data['sessionToken'] as String?;

        if (uid == null || sessionToken == null) {
          debugPrint('백엔드 인증 응답 형식이 올바르지 않습니다.');
          return null;
        }

        // 💡 이후 모든 인증 API 요청에 사용할 세션 토큰 저장
        await ApiClient.setSessionToken(sessionToken);
        // 💡 온보딩 완료 플래그 저장 (다음 실행부터 온보딩 건너뜀)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);
        debugPrint('백엔드 인증 성공');
        return (
          uid: uid,
          sessionToken: sessionToken,
          email: usableAccountEmail(data['email']) ?? '',
          profileImageUrl: usableProfileImageUrl(data['profileImageUrl']),
        );
      } else {
        debugPrint('백엔드 인증 실패: ${response.statusCode}');
        return null;
      }
    } catch (_) {
      debugPrint('백엔드 통신 오류가 발생했습니다.');
      return null;
    }
  }

  /// Ends the Kakao app connection after the server already deleted the
  /// account. Withdrawal is complete at that point, so failure only logs.
  Future<void> unlinkKakaoAfterWithdrawal() async {
    try {
      await _unlinkKakao().timeout(const Duration(seconds: 10));
      debugPrint('카카오 연결 끊기 성공');
    } catch (_) {
      debugPrint('카카오 연결 끊기에 실패했지만 탈퇴는 이미 완료됐습니다.');
    }
  }

  Future<void> logout() async {
    try {
      await UserApi.instance.logout();
      debugPrint('카카오 로그아웃 성공');
    } catch (_) {
      debugPrint('카카오 로그아웃 요청에 실패해 로컬 세션만 정리합니다.');
    } finally {
      // 기기 푸시 해제도 세션 토큰으로 인증하므로, 서버 세션 폐기는 그 다음에 합니다.
      try {
        await _ref
            .read(pushNotificationServiceProvider)
            .unregisterCurrentDevice();
      } finally {
        await _revokeServerSession();
        await clearLocalSession(unregisterDevice: false);
      }
    }
  }

  /// 이 기기의 서버 세션 토큰을 폐기합니다. 같은 계정의 다른 기기 세션은 유지됩니다.
  /// 오프라인이거나 서버가 응답하지 않아도 이 기기의 로그아웃은 계속합니다.
  Future<void> _revokeServerSession() async {
    if (!ApiClient.isAuthenticated) return;
    try {
      await http
          .post(
            ApiClient.uri('/api/auth/logout'),
            headers: ApiClient.authHeaders(auth: true),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      debugPrint('서버 세션 폐기 요청에 실패했습니다. 이 기기에서는 로그아웃합니다.');
    }
  }

  Future<void> clearLocalSession({bool unregisterDevice = true}) async {
    try {
      if (unregisterDevice) {
        await _ref
            .read(pushNotificationServiceProvider)
            .unregisterCurrentDevice();
      }
    } finally {
      await ApiClient.setSessionToken(null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kakaoProfileImagePreferenceKey);
      await prefs.remove(kakaoEmailPreferenceKey);
      _ref.read(authStateProvider.notifier).state = const AuthState(
        isLoggedIn: false,
        provider: '',
        email: '',
      );
      _ref.read(userProfileProvider.notifier).state = UserProfile.guest;
      _ref.read(userReportsProvider.notifier).setReports(const []);
    }
  }
}
