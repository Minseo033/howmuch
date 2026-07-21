import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:howmuch/core/network/api_client.dart';

/// 사용자 프로필 API 서비스.
/// 세션 토큰(Authorization: Bearer)으로 인증하며, uid는 서버가 세션에서 식별합니다.
class UserProfileApiService {
  /// 사용자 프로필 조회
  /// 성공 시 Map 반환, 404(신규 사용자)면 null 반환
  Future<Map<String, dynamic>?> fetchProfile() async {
    final url = ApiClient.uri('/api/user/profile');
    try {
      final response = await http
          .get(url, headers: ApiClient.jsonHeaders(auth: true))
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('프로필 조회 성공: $data');
        return data;
      } else if (response.statusCode == 404) {
        debugPrint('프로필 없음 (신규 사용자)');
        return null;
      } else {
        debugPrint('프로필 조회 실패: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('프로필 조회 통신 에러: $e');
      return null;
    }
  }

  /// 사용자 프로필 저장 (최초 설정)
  Future<bool> saveProfile({
    required String nickname,
    required String email,
    required String region,
    required List<String> favoriteCategories,
  }) async {
    final url = ApiClient.uri('/api/user/profile');
    try {
      final response = await http
          .post(
            url,
            headers: ApiClient.jsonHeaders(auth: true),
            body: jsonEncode({
              'nickname': nickname,
              'email': email,
              'region': region,
              'favoriteCategories': favoriteCategories,
            }),
          )
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('프로필 저장 성공');
        return true;
      } else {
        debugPrint('프로필 저장 실패: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('프로필 저장 통신 에러: $e');
      return false;
    }
  }
}