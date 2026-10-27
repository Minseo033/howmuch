import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/system/presentation/state/push_notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the moment the device registration is removed, which also needs
/// the session token, so the test can check the order of logout steps.
class _RecordingPush extends PushNotificationService {
  _RecordingPush(super.ref, this.calls);

  final List<String> calls;

  @override
  Future<void> unregisterCurrentDevice({String? sessionToken}) async {
    calls.add('unregister with ${ApiClient.sessionToken ?? 'no token'}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('session-1');
    calls = [];
    container = ProviderContainer(
      overrides: [
        pushNotificationServiceProvider.overrideWith(
          (ref) => _RecordingPush(ref, calls),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await ApiClient.setSessionToken(null);
  });

  test('logout revokes this device session on the server, then clears it locally', () async {
    await http.runWithClient(
      () => container.read(kakaoLoginServiceProvider).logout(),
      () => MockClient((request) async {
        calls.add(
          '${request.method} ${request.url.path} ${request.headers['Authorization']}',
        );
        return http.Response('{"success":true,"revoked":true}', 200);
      }),
    );

    expect(calls, [
      'unregister with session-1',
      'POST /api/auth/logout Bearer session-1',
    ]);
    expect(ApiClient.sessionToken, isNull);
  });

  test('logout still signs out this device when the server cannot be reached', () async {
    await http.runWithClient(
      () => container.read(kakaoLoginServiceProvider).logout(),
      () => MockClient((request) async => throw http.ClientException('offline')),
    );

    expect(ApiClient.sessionToken, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('howmuch_session_token'), isNull);
  });
}
