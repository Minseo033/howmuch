import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UserProfileApiService {
  static const String _backendBaseUrl =
      'https://howmuch-backend-1xnu.onrender.com';

  static const Map<String, String> _baseHeaders = {
    'Content-Type': 'application/json',
  };

  /// 사용자 프로필 조회
  /// 성공 시 Map 반환, 404면 null 반환
  Future<Map<String, dynamic>?> fetchProfile(String firebaseUid) async {
    final url = Uri.parse('$_backendBaseUrl/api/user/profile');
    try {
      final response = await http
          .get(url, headers: {..._baseHeaders, 'X-Firebase-Uid': firebaseUid})
          .timeout(const Duration(seconds: 10));

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
  Future<bool> saveProfile(
    String firebaseUid, {
    required String nickname,
    required String email,
    required String region,
    required List<String> favoriteCategories,
  }) async {
    final url = Uri.parse('$_backendBaseUrl/api/user/profile');
    try {
      final response = await http
          .post(
            url,
            headers: {..._baseHeaders, 'X-Firebase-Uid': firebaseUid},
            body: jsonEncode({
              'nickname': nickname,
              'email': email,
              'region': region,
              'favoriteCategories': favoriteCategories,
            }),
          )
          .timeout(const Duration(seconds: 10));

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
