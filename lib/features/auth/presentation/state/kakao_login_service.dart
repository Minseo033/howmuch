import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/app/app_router.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/mypage/presentation/state/user_profile_api_service.dart';

final kakaoLoginServiceProvider = Provider((ref) => KakaoLoginService(ref));

class KakaoLoginService {
  final Ref _ref;

  KakaoLoginService(this._ref);

  Future<String?> login() async {
    try {
      bool isInstalled = await isKakaoTalkInstalled();

      OAuthToken token;
      if (isInstalled) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
          debugPrint('카카오톡으로 로그인 성공');
        } catch (error) {
          debugPrint('카카오톡으로 로그인 실패 $error');
          _ref.read(appRouterProvider).go(AppRoutes.login);
          if (error is KakaoClientException && error.msg == 'Canceled') {
            return '사용자가 취소했습니다.';
          }
          return '카카오톡 앱 로그인 실패: $error';
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
        debugPrint('카카오계정으로 로그인 성공');
      }

      final session = await _authenticateWithBackend(token.accessToken);
      if (session != null) {
        User user = await UserApi.instance.me();
        final email = user.kakaoAccount?.email ?? 'unknown';
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
              ),
            );

        // 💡 프로필 존재 여부에 따라 라우팅 분기
        final profileService = UserProfileApiService();
        final profile = await profileService.fetchProfile();

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
                  email: profile['email'] as String? ?? email,
                  region: profile['region'] as String? ?? state.region,
                  favoriteCategories:
                      parsedCategories ?? state.favoriteCategories,
                ),
              );
          _ref.read(appRouterProvider).go(AppRoutes.home);
        } else {
          // 신규 사용자: 프로필 설정 화면으로 이동
          _ref.read(appRouterProvider).go(AppRoutes.profileSetup);
        }

        return null; // 성공 시 null 반환
      } else {
        _ref.read(appRouterProvider).go(AppRoutes.login);
        return '백엔드 인증 실패';
      }
    } catch (e) {
      debugPrint('카카오톡 로그인 로직 에러: $e');
      _ref.read(appRouterProvider).go(AppRoutes.login);
      return '통신 에러: $e';
    }
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
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final uid = data['firebaseUid'] as String?;
        final sessionToken = data['sessionToken'] as String?;

        if (uid == null || sessionToken == null) {
          debugPrint('백엔드 인증 응답 형식 오류: $data');
          return null;
        }

        // 💡 이후 모든 인증 API 요청에 사용할 세션 토큰 저장
        await ApiClient.setSessionToken(sessionToken);
        debugPrint('백엔드 인증 성공: uid=$uid');
        return (uid: uid, sessionToken: sessionToken);
      } else {
        debugPrint('백엔드 인증 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('백엔드 통신 에러: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await UserApi.instance.logout();
      // 💡 세션 토큰도 함께 폐기 (서버 API 인증 불가 처리)
      await ApiClient.setSessionToken(null);
      _ref
          .read(authStateProvider.notifier)
          .update(
            (state) => state.copyWith(
              isLoggedIn: false,
              email: '',
              firebaseUid: '',
              sessionToken: '',
            ),
          );
      debugPrint('로그아웃 성공');
    } catch (error) {
      debugPrint('로그아웃 실패 $error');
    }
  }
}
