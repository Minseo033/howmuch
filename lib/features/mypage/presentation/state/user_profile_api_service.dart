import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:howmuch/core/network/api_client.dart';

class UserProfileAuthException implements Exception {
  const UserProfileAuthException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'UserProfileAuthException($statusCode)';
}

class UserProfileLoadException implements Exception {
  const UserProfileLoadException([this.message]);

  final String? message;

  @override
  String toString() => 'UserProfileLoadException($message)';
}

/// 사용자 프로필 API 서비스.
/// 세션 토큰(Authorization: Bearer)으로 인증하며, uid는 서버가 세션에서 식별합니다.
class UserProfileApiService {
  /// 사용자 프로필 조회
  /// 성공 시 Map 반환, 404(신규 사용자)면 null 반환
  Future<Map<String, dynamic>?> fetchProfile({bool strict = false}) async {
    final url = ApiClient.uri('/api/user/profile');
    try {
      final response = await http
          .get(url, headers: ApiClient.jsonHeaders(auth: true))
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        debugPrint('프로필 조회 성공: $data');
        return data;
      } else if (response.statusCode == 404) {
        debugPrint('프로필 없음 (신규 사용자)');
        return null;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('프로필 조회 인증 실패: ${response.statusCode}');
        throw UserProfileAuthException(response.statusCode);
      } else {
        final body = ApiClient.bodyText(response);
        debugPrint('프로필 조회 실패: ${response.statusCode} $body');
        if (strict) {
          throw UserProfileLoadException('${response.statusCode} $body');
        }
        return null;
      }
    } catch (e) {
      if (e is UserProfileAuthException || e is UserProfileLoadException) {
        rethrow;
      }
      debugPrint('프로필 조회 통신 에러: $e');
      if (strict) {
        throw UserProfileLoadException(e.toString());
      }
      return null;
    }
  }

  /// 사용자 프로필 저장 (최초 설정)
  Future<bool> saveProfile({
    required String nickname,
    required String email,
    required String region,
    required List<String> favoriteCategories,
    bool? nicknamePublic,
    bool? activityPublic,
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
              if (nicknamePublic != null) 'nicknamePublic': nicknamePublic,
              if (activityPublic != null) 'activityPublic': activityPublic,
            }),
          )
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('프로필 저장 성공');
        return true;
      } else {
        debugPrint(
          '프로필 저장 실패: ${response.statusCode} ${ApiClient.bodyText(response)}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('프로필 저장 통신 에러: $e');
      return false;
    }
  }
}
