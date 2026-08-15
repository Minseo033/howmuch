import 'package:shared_preferences/shared_preferences.dart';

/// 백엔드 API 공통 클라이언트.
///
/// - 베이스 URL을 한 곳에서 관리합니다 (하드코딩 중복 제거).
///   빌드 시 `--dart-define=BACKEND_BASE_URL=...`로 덮어쓸 수 있습니다.
/// - 로그인 후 발급받은 세션 토큰을 보관하고, 인증이 필요한 요청에
///   Authorization: Bearer 헤더를 자동으로 붙입니다.
class ApiClient {
  ApiClient._();

  static const String baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://howmuch-backend-1xnu.onrender.com',
  );

  static const Duration defaultTimeout = Duration(seconds: 15);

  static const String _sessionTokenKey = 'howmuch_session_token';
  static String? _sessionToken;

  static String? get sessionToken => _sessionToken;
  static bool get isAuthenticated =>
      _sessionToken != null && _sessionToken!.isNotEmpty;

  /// 앱 시작 시 기기에 저장된 세션 토큰을 복원합니다.
  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionToken = prefs.getString(_sessionTokenKey);
  }

  /// 세션 토큰을 저장/삭제합니다 (로그인 성공 시 저장, 로그아웃 시 null).
  static Future<void> setSessionToken(String? token) async {
    _sessionToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_sessionTokenKey);
    } else {
      await prefs.setString(_sessionTokenKey, token);
    }
  }

  /// API URL 생성. [queryParameters]는 필요할 때만 전달합니다.
  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    final uri = Uri.parse('$baseUrl$path');
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  /// JSON 요청 공통 헤더. [auth]가 true면 세션 토큰을 첨부합니다.
  static Map<String, String> jsonHeaders({bool auth = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth && _sessionToken != null) {
      headers['Authorization'] = 'Bearer $_sessionToken';
    }
    return headers;
  }
}