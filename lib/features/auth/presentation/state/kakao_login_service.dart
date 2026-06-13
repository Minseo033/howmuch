import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';

final kakaoLoginServiceProvider = Provider((ref) => KakaoLoginService(ref));

class KakaoLoginService {
  final Ref _ref;
  // 💡 실기기 테스트를 위해 PC의 IP 주소를 사용합니다.
  final String _backendHost = kIsWeb ? 'localhost' : '192.168.0.13';

  KakaoLoginService(this._ref);

  Future<bool> login() async {
    try {
      bool isInstalled = await isKakaoTalkInstalled();

      OAuthToken token;
      if (isInstalled) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
          debugPrint('카카오톡으로 로그인 성공');
        } catch (error) {
          debugPrint('카카오톡으로 로그인 실패 $error');
          // 사용자가 카카오톡 설치 후 로그인을 취소한 경우,
          // 의도적인 취소로 간주하여 예외 처리
          if (error is KakaoClientException && error.msg == 'Canceled') {
            return false;
          }
          // 카카오톡에 연결된 카카오계정이 없는 경우, 카카오계정으로 로그인
          token = await UserApi.instance.loginWithKakaoAccount();
          debugPrint('카카오계정으로 로그인 성공');
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
        debugPrint('카카오계정으로 로그인 성공');
      }

      return await _authenticateWithBackend(token.accessToken);
    } catch (error) {
      debugPrint('카카오 로그인 실패 $error');
      return false;
    }
  }

  Future<bool> _authenticateWithBackend(String accessToken) async {
    final url = Uri.parse('http://$_backendHost:8081/api/auth/kakao');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'kakaoAccessToken': accessToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final customToken = data['customToken'];
        debugPrint('백엔드 인증 성공: $customToken');

        // 💡 사용자 정보 가져오기
        User user = await UserApi.instance.me();
        
        // 💡 인증 상태 업데이트
        _ref.read(authStateProvider.notifier).update((state) => state.copyWith(
          isLoggedIn: true,
          provider: '카카오',
          email: user.kakaoAccount?.email ?? 'unknown',
        ));
        
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
