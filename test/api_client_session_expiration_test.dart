import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.setSessionExpiredHandler(null);
    await ApiClient.setSessionToken('session-token');
  });

  tearDown(() async {
    ApiClient.setSessionExpiredHandler(null);
    await ApiClient.setSessionToken(null);
  });

  test('인증 요청의 401은 세션을 한 번만 만료시킨다', () async {
    var expirationCount = 0;
    ApiClient.setSessionExpiredHandler(() async {
      expirationCount++;
    });

    const headers = {'Authorization': 'Bearer session-token'};
    await ApiClient.handleResponseStatus(401, requestHeaders: headers);
    await ApiClient.handleResponseStatus(401, requestHeaders: headers);

    expect(expirationCount, 1);
    expect(ApiClient.sessionToken, isNull);
  });

  test('인증 헤더가 없는 401과 권한 부족 403은 세션을 유지한다', () async {
    var expirationCount = 0;
    ApiClient.setSessionExpiredHandler(() async {
      expirationCount++;
    });

    await ApiClient.handleResponseStatus(401);
    await ApiClient.handleResponseStatus(
      403,
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    expect(expirationCount, 0);
    expect(ApiClient.sessionToken, 'session-token');
  });

  test('새 로그인 토큰은 다음 세션 만료 처리를 다시 허용한다', () async {
    var expirationCount = 0;
    ApiClient.setSessionExpiredHandler(() async {
      expirationCount++;
    });

    const headers = {'Authorization': 'Bearer session-token'};
    await ApiClient.handleResponseStatus(401, requestHeaders: headers);
    await ApiClient.setSessionToken('next-session-token');
    await ApiClient.handleResponseStatus(
      401,
      requestHeaders: const {'Authorization': 'Bearer next-session-token'},
    );

    expect(expirationCount, 2);
    expect(ApiClient.sessionToken, isNull);
  });

  test('인증 저장소의 일시 장애 503은 저장된 세션을 유지한다', () async {
    var expirationCount = 0;
    ApiClient.setSessionExpiredHandler(() async => expirationCount++);
    await ApiClient.handleResponseStatus(
      503,
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    expect(expirationCount, 0);
    expect(ApiClient.sessionToken, 'session-token');
    await ApiClient.restoreSession();
    expect(ApiClient.sessionToken, 'session-token');
  });

  test('이전 로그인 요청의 늦은 401은 새 세션을 만료시키지 않는다', () async {
    var expirationCount = 0;
    ApiClient.setSessionExpiredHandler(() async => expirationCount++);
    final oldHeaders = ApiClient.jsonHeaders(auth: true);
    await ApiClient.setSessionToken('new-session');

    await ApiClient.handleResponseStatus(401, requestHeaders: oldHeaders);

    expect(ApiClient.sessionToken, 'new-session');
    expect(expirationCount, 0);
    await ApiClient.handleResponseStatus(
      401,
      requestHeaders: const {'authorization': 'Bearer new-session'},
    );
    expect(expirationCount, 1);
  });

  test('GET은 Content-Type 사전 요청 헤더를 제거하고 인증 헤더는 유지한다', () async {
    late http.Request capturedRequest;
    await http.runWithClient(
      () => ApiClient.get(
        Uri.https('example.test', '/api/stores/all'),
        headers: ApiClient.jsonHeaders(auth: true),
      ),
      () => MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 200);
      }),
    );

    expect(capturedRequest.headers.containsKey('content-type'), isFalse);
    expect(capturedRequest.headers['accept'], 'application/json');
    expect(capturedRequest.headers['authorization'], 'Bearer session-token');
  });
}
