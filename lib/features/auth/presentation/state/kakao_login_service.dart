import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/app/app_router.dart';

final kakaoLoginServiceProvider = Provider((ref) => KakaoLoginService(ref));

class KakaoLoginService {
  final Ref _ref;
  // 💡 실기기 및 로컬 네트워크 제약을 우회하기 위해 ngrok 터널링 주소를 사용합니다.
  final String _backendBaseUrl = kIsWeb ? 'http://localhost:8081' : 'https://sulfurously-transhumant-dennise.ngrok-free.dev';

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

      bool isBackendSuccess = await _authenticateWithBackend(token.accessToken);
      if (isBackendSuccess) {
        User user = await UserApi.instance.me();
        
        // 💡 인증 상태 업데이트
        _ref.read(authStateProvider.notifier).update((state) => state.copyWith(
          isLoggedIn: true,
          provider: '카카오',
          email: user.kakaoAccount?.email ?? 'unknown',
        ));
        
        _ref.read(appRouterProvider).go(AppRoutes.permissionSetup);
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

  Future<bool> _authenticateWithBackend(String accessToken) async {
    final url = Uri.parse('$_backendBaseUrl/api/auth/kakao');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true' // ngrok 경고 페이지 우회
        },
        body: jsonEncode({'kakaoAccessToken': accessToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final customToken = data['customToken'];
        debugPrint('백엔드 인증 성공: $customToken');
        
        return true;
      } else {
        debugPrint('백엔드 인증 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('백엔드 통신 에러: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await UserApi.instance.logout();
      _ref.read(authStateProvider.notifier).update((state) => state.copyWith(
        isLoggedIn: false,
        email: '',
      ));
      debugPrint('로그아웃 성공');
    } catch (error) {
      debugPrint('로그아웃 실패 $error');
    }
  }
}
