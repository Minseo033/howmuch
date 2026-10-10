import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/system/presentation/state/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Logging in registers this device by itself, and the push switch registers
/// again right after a guest logs in from it. One session never runs two
/// registrations at once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ApiClient.setSessionToken(null));

  test('calls for one session share the running registration', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final push = container.read(pushNotificationServiceProvider);
    await ApiClient.setSessionToken('first-session');

    final atLogin = push.registerForCurrentSession();
    final fromSwitch = push.registerForCurrentSession();
    expect(identical(fromSwitch, atLogin), isTrue);

    await ApiClient.setSessionToken('second-session');
    final otherSession = push.registerForCurrentSession();
    expect(identical(otherSession, atLogin), isFalse);

    await Future.wait([atLogin, otherSession]);
    final nextTap = push.registerForCurrentSession();
    expect(identical(nextTap, otherSession), isFalse);
    await nextTap;
  });
}
