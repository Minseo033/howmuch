import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/state/user_profile_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('404 is the only profile response treated as a new user', () async {
    final service = UserProfileApiService(
      client: MockClient((_) async => http.Response('{}', 404)),
    );

    expect(await service.fetchProfile(), isNull);
  });

  test('server failure is never treated as a missing profile', () async {
    final service = UserProfileApiService(
      client: MockClient((_) async => http.Response('server error', 500)),
    );

    await expectLater(
      service.fetchProfile(),
      throwsA(isA<UserProfileLoadException>()),
    );
  });

  test('network failure is never treated as a missing profile', () async {
    final service = UserProfileApiService(
      client: MockClient((_) async => throw Exception('network unavailable')),
    );

    await expectLater(
      service.fetchProfile(),
      throwsA(isA<UserProfileLoadException>()),
    );
  });
}
