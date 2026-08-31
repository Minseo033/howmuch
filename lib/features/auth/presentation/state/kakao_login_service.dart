import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/app/app_router.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/state/user_profile_api_service.dart';
import 'package:howmuch/features/system/presentation/state/push_notification_service.dart';

final kakaoLoginServiceProvider = Provider((ref) => KakaoLoginService(ref));

class KakaoLoginService {
  final Ref _ref;

  KakaoLoginService(this._ref);

  Future<String?> login() async {
    var backendSessionEstablished = false;
    try {
      bool isInstalled = await isKakaoTalkInstalled();

      OAuthToken token;
      if (isInstalled) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
          debugPrint('카카오톡으로 로그인 성공');
        } catch (error) {
          debugPrint('카카오톡으로 로그인하지 못했습니다.');
          _ref.read(appRouterProvider).go(AppRoutes.login);
          if (error is KakaoClientException && error.msg == 'Canceled') {
            return '사용자가 취소했습니다.';
          }
          return '카카오톡 앱 로그인에 실패했습니다. 잠시 후 다시 시도해주세요.';
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
        debugPrint('카카오계정으로 로그인 성공');
      }

      final session = await _authenticateWithBackend(token.accessToken);
      if (session != null) {
        backendSessionEstablished = true;
        User user = await UserApi.instance.me();
        var email = usableAccountEmail(user.kakaoAccount?.email) ?? '';
        if (email.isEmpty && user.kakaoAccount?.emailNeedsAgreement == true) {
          try {
            await UserApi.instance.loginWithNewScopes(const ['account_email']);
            user = await UserApi.instance.me();
            email = usableAccountEmail(user.kakaoAccount?.email) ?? '';
          } catch (error) {
            debugPrint('카카오 이메일 추가 동의를 완료하지 못했습니다: $error');
          }
        }
        final kakaoProfile = user.kakaoAccount?.profile;
        final profileImageUrl =
            (kakaoProfile?.profileImageUrl ?? kakaoProfile?.thumbnailImageUrl)
                ?.toString()
                .trim() ??
            '';
        // 백엔드가 발급한 공식 uid/세션 토큰을 사용합니다.
        final firebaseUid = session.uid;

        final prefs = await SharedPreferences.getInstance();
        if (email.isNotEmpty) {
          await prefs.setString(kakaoEmailPreferenceKey, email);
        }
        if (profileImageUrl.isNotEmpty) {
          await prefs.setString(
            kakaoProfileImagePreferenceKey,
            profileImageUrl,
          );
        } else {
          await prefs.remove(kakaoProfileImagePreferenceKey);
        }

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
        final profileService = UserProfileApiService();
        // Only a 404 means that profile setup is required. A temporary server
        // or network failure must never be mistaken for a new account.
        final profile = await profileService.fetchProfile(strict: true);

        if (profile != null) {
          // 기존 사용자: 프로필 데이터로 상태 업데이트 후 홈으로 이동
          final rawCategories = profile['favoriteCategories'];
          final parsedCategories = rawCategories is List
              ? rawCategories.map((e) => e.toString()).toList()
              : null;
          _ref
              .read(userProfileProvider.notifier)
              .update(
                (state) => state.copyWith(
                  nickname: profile['nickname'] as String? ?? state.nickname,
                  email: usableAccountEmail(profile['email']) ?? email,
                  region: profile['region'] as String? ?? state.region,
                  favoriteCategories:
                      parsedCategories ?? state.favoriteCategories,
                  profileImageUrl: profileImageUrl,
                ),
              );
          _ref.read(appRouterProvider).go(AppRoutes.home);
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
          _ref.read(appRouterProvider).go(AppRoutes.profileSetup);
        }

        return null; // 성공 시 null 반환
      } else {
        _ref.read(appRouterProvider).go(AppRoutes.login);
        return '백엔드 인증 실패';
      }
    } catch (_) {
      debugPrint('카카오 로그인 처리 중 오류가 발생했습니다.');
      if (backendSessionEstablished) {
        await clearLocalSession(unregisterDevice: false);
      }
      _ref.read(appRouterProvider).go(AppRoutes.login);
      return '로그인 중 통신 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }
  }

  Future<String?> refreshKakaoEmail({bool requestConsent = false}) async {
    final prefs = await SharedPreferences.getInstance();
    var email = usableAccountEmail(prefs.getString(kakaoEmailPreferenceKey));

    try {
      var user = await UserApi.instance.me();
      email = usableAccountEmail(user.kakaoAccount?.email) ?? email;
      if (email == null &&
          requestConsent &&
          user.kakaoAccount?.emailNeedsAgreement == true) {
        await UserApi.instance.loginWithNewScopes(const ['account_email']);
        user = await UserApi.instance.me();
        email = usableAccountEmail(user.kakaoAccount?.email);
      }
    } catch (error) {
      debugPrint('카카오 이메일 갱신 실패: $error');
    }

    if (email == null) return null;
    final resolvedEmail = email;
    await prefs.setString(kakaoEmailPreferenceKey, resolvedEmail);
    _ref
        .read(authStateProvider.notifier)
        .update((state) => state.copyWith(email: resolvedEmail));
    _ref
        .read(userProfileProvider.notifier)
        .update((state) => state.copyWith(email: resolvedEmail));
    return resolvedEmail;
  }

  Future<({String uid, String sessionToken})?> _authenticateWithBackend(
    String accessToken,
  ) async {
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
        return (uid: uid, sessionToken: sessionToken);
      } else {
        debugPrint('백엔드 인증 실패: ${response.statusCode}');
        return null;
      }
    } catch (_) {
      debugPrint('백엔드 통신 오류가 발생했습니다.');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await UserApi.instance.logout();
      debugPrint('카카오 로그아웃 성공');
    } catch (_) {
      debugPrint('카카오 로그아웃 요청에 실패해 로컬 세션만 정리합니다.');
    } finally {
      await clearLocalSession();
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
