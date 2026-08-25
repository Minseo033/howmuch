import 'dart:convert';

import 'package:http/http.dart' as http;
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
  static Future<void> Function()? _sessionExpiredHandler;
  static bool _sessionExpirationHandled = false;
  static Future<void>? _sessionExpirationInFlight;

  static String? get sessionToken => _sessionToken;
  static bool get isAuthenticated =>
      _sessionToken != null && _sessionToken!.isNotEmpty;

  /// 앱 시작 시 기기에 저장된 세션 토큰을 복원합니다.
  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionToken = prefs.getString(_sessionTokenKey);
    _sessionExpirationHandled = false;
  }

  /// 세션 토큰을 저장/삭제합니다 (로그인 성공 시 저장, 로그아웃 시 null).
  static Future<void> setSessionToken(String? token) async {
    _sessionToken = token;
    if (token != null && token.isNotEmpty) {
      _sessionExpirationHandled = false;
    }
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_sessionTokenKey);
    } else {
      await prefs.setString(_sessionTokenKey, token);
    }
  }

  static void setSessionExpiredHandler(Future<void> Function()? handler) {
    _sessionExpiredHandler = handler;
  }

  /// 인증 헤더가 포함된 요청이 401을 받은 경우에만 세션 만료를 처리합니다.
  /// 동시에 여러 요청이 실패해도 로그아웃과 화면 전환은 한 번만 실행됩니다.
  static Future<void> handleResponseStatus(
    int statusCode, {
    Map<String, String>? requestHeaders,
  }) async {
    final hadAuthorization = requestHeaders?.keys.any(
      (key) => key.toLowerCase() == 'authorization',
    );
    if (statusCode != 401 || hadAuthorization != true) return;
    if (_sessionExpirationHandled) return;
    if (_sessionExpirationInFlight != null) {
      await _sessionExpirationInFlight;
      return;
    }

    final future = _expireSession();
    _sessionExpirationInFlight = future;
    try {
      await future;
    } finally {
      _sessionExpirationInFlight = null;
    }
  }

  static Future<void> _expireSession() async {
    if (_sessionExpirationHandled) return;
    _sessionExpirationHandled = true;
    await setSessionToken(null);
    await _sessionExpiredHandler?.call();
  }

  static http.Client createHttpClient() => _SessionAwareHttpClient();

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final response = await http.get(url, headers: headers);
    await handleResponseStatus(response.statusCode, requestHeaders: headers);
    return response;
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final response = await http.post(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
    await handleResponseStatus(response.statusCode, requestHeaders: headers);
    return response;
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final response = await http.put(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
    await handleResponseStatus(response.statusCode, requestHeaders: headers);
    return response;
  }

  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final response = await http.patch(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
    await handleResponseStatus(response.statusCode, requestHeaders: headers);
    return response;
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final response = await http.delete(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
    await handleResponseStatus(response.statusCode, requestHeaders: headers);
    return response;
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
    final headers = authHeaders(auth: auth);
    headers['Content-Type'] = 'application/json';
    return headers;
  }

  /// 인증만 필요한 multipart 요청용 헤더입니다. Content-Type과 boundary는
  /// MultipartRequest가 직접 만들도록 비워둡니다.
  static Map<String, String> authHeaders({bool auth = false}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (auth && _sessionToken != null) {
      headers['Authorization'] = 'Bearer $_sessionToken';
    }
    return headers;
  }

  /// 서버가 charset을 생략해도 한글 JSON이 깨지지 않도록 UTF-8로 읽습니다.
  static dynamic decodeJson(http.Response response) {
    return jsonDecode(bodyText(response));
  }

  static String bodyText(http.Response response) {
    return utf8.decode(response.bodyBytes);
  }
}

class _SessionAwareHttpClient extends http.BaseClient {
  _SessionAwareHttpClient() : _inner = http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    await ApiClient.handleResponseStatus(
      response.statusCode,
      requestHeaders: request.headers,
    );
    return response;
  }

  @override
  void close() => _inner.close();
}
