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
  static final Map<String, _CachedRead> _readCache = {};
  static int _readCacheRevision = 0;

  /// Screens use this to refresh retained data after a successful mutation.
  static int get readCacheRevision => _readCacheRevision;

  static void invalidateReadCache({Set<String>? paths}) {
    _readCacheRevision++;
    if (paths == null) {
      _readCache.clear();
    } else {
      _readCache.removeWhere((_, entry) => paths.contains(entry.path));
    }
  }

  static void _invalidateAfterWrite(String method, Uri uri, int status) {
    if (method == 'GET' ||
        status < 200 ||
        status >= 300 ||
        uri.origin != Uri.parse(baseUrl).origin) {
      return;
    }
    final path = uri.path;
    if (path == '/api/savings/goal') {
      invalidateReadCache(paths: {'/api/savings/goal'});
    } else if (path.startsWith('/api/favorites')) {
      invalidateReadCache(paths: {'/api/favorites'});
    } else if (path.startsWith('/api/visits')) {
      invalidateReadCache(
        paths: {'/api/savings/stats', '/api/savings/history'},
      );
    } else if (path.startsWith('/api/report/') &&
        !path.startsWith('/api/report/images')) {
      invalidateReadCache(paths: {'/api/report/my'});
    } else if (path == '/api/user/profile') {
      invalidateReadCache(paths: {'/api/user/profile'});
    }
  }

  static String? get sessionToken => _sessionToken;
  static bool get isAuthenticated =>
      _sessionToken != null && _sessionToken!.isNotEmpty;

  /// 앱 시작 시 기기에 저장된 세션 토큰을 복원합니다.
  static Future<void> restoreSession({SharedPreferences? preferences}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    invalidateReadCache();
    _sessionToken = prefs.getString(_sessionTokenKey);
    _sessionExpirationHandled = false;
  }

  /// 세션 토큰을 저장/삭제합니다 (로그인 성공 시 저장, 로그아웃 시 null).
  static Future<void> setSessionToken(String? token) async {
    invalidateReadCache();
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
    if (statusCode != 401 || !isAuthenticated) return;
    final authorization = requestHeaders?.entries
        .where((entry) => entry.key.toLowerCase() == 'authorization')
        .firstOrNull
        ?.value;
    // A request sent before logout/re-login must not expire the new session.
    if (authorization != 'Bearer $_sessionToken') return;
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
    Duration timeout = defaultTimeout,
    Duration? cacheMaxAge,
  }) async {
    // A GET has no request body. Sending Content-Type is unnecessary and
    // forces cross-origin browsers to make a CORS preflight before every GET.
    final requestHeaders = headers == null
        ? null
        : Map<String, String>.fromEntries(
            headers.entries.where(
              (entry) => entry.key.toLowerCase() != 'content-type',
            ),
          );
    final authorization = requestHeaders?['Authorization'];
    if (cacheMaxAge == Duration.zero) {
      // An explicit refresh must not leave an older cached version available
      // for the next normal visit. Its caller already owns the UI refresh.
      _readCache.removeWhere((_, entry) => entry.path == url.path);
    }
    final cacheable =
        cacheMaxAge != null &&
        cacheMaxAge > Duration.zero &&
        isAuthenticated &&
        authorization == 'Bearer $_sessionToken' &&
        url.origin == Uri.parse(baseUrl).origin;
    if (!cacheable) return _get(url, requestHeaders, timeout);
    final headerKeys = requestHeaders!.keys.toList()..sort();
    final key =
        '$url\n${timeout.inMilliseconds}\n${headerKeys.map((name) => '$name:${requestHeaders[name]}').join('\n')}';
    final cached = _readCache[key];
    if (cached != null &&
        (cached.completedAt == null ||
            DateTime.now().difference(cached.completedAt!) < cacheMaxAge)) {
      return cached.response;
    }
    // The cache is account scoped, small and memory only. Removing an entry
    // on a write also detaches any old in-flight read from the new generation.
    if (_readCache.length >= 64) _readCache.remove(_readCache.keys.first);
    final entry = _CachedRead(url.path);
    _readCache[key] = entry;
    entry.response = _get(url, requestHeaders, timeout).then(
      (response) {
        if (response.statusCode == 200) {
          entry.completedAt = DateTime.now();
        } else if (identical(_readCache[key], entry)) {
          _readCache.remove(key);
        }
        return response;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_readCache[key], entry)) _readCache.remove(key);
        Error.throwWithStackTrace(error, stack);
      },
    );
    return entry.response;
  }

  static Future<http.Response> _get(
    Uri url,
    Map<String, String>? requestHeaders,
    Duration timeout,
  ) async {
    final response = await http
        .get(url, headers: requestHeaders)
        .timeout(timeout);
    await handleResponseStatus(
      response.statusCode,
      requestHeaders: requestHeaders,
    );
    return response;
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = defaultTimeout,
  }) async {
    final response = await http
        .post(url, headers: headers, body: body, encoding: encoding)
        .timeout(timeout);
    _invalidateAfterWrite('POST', url, response.statusCode);
    await handleResponseStatus(response.statusCode, requestHeaders: headers);
    return response;
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = defaultTimeout,
  }) async {
    final response = await http
        .put(url, headers: headers, body: body, encoding: encoding)
        .timeout(timeout);
    _invalidateAfterWrite('PUT', url, response.statusCode);
    await handleResponseStatus(response.statusCode, requestHeaders: headers);
    return response;
  }

  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = defaultTimeout,
  }) async {
    final response = await http
        .patch(url, headers: headers, body: body, encoding: encoding)
        .timeout(timeout);
    _invalidateAfterWrite('PATCH', url, response.statusCode);
    await handleResponseStatus(response.statusCode, requestHeaders: headers);
    return response;
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = defaultTimeout,
  }) async {
    final response = await http
        .delete(url, headers: headers, body: body, encoding: encoding)
        .timeout(timeout);
    _invalidateAfterWrite('DELETE', url, response.statusCode);
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

class _CachedRead {
  _CachedRead(this.path);
  final String path;
  late final Future<http.Response> response;
  DateTime? completedAt;
}

class _SessionAwareHttpClient extends http.BaseClient {
  _SessionAwareHttpClient() : _inner = http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    ApiClient._invalidateAfterWrite(
      request.method,
      request.url,
      response.statusCode,
    );
    await ApiClient.handleResponseStatus(
      response.statusCode,
      requestHeaders: request.headers,
    );
    return response;
  }

  @override
  void close() => _inner.close();
}
