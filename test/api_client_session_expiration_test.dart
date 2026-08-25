import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
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
}
