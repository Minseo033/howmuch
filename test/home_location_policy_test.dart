import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';

void main() {
  test(
    'home map uses only recent cached locations for immediate centering',
    () {
      final now = DateTime.utc(2026, 8, 19, 12);

      expect(
        isFreshHomeLocation(now.subtract(maxHomeLocationCacheAge), now),
        isTrue,
      );
      expect(
        isFreshHomeLocation(
          now.subtract(
            maxHomeLocationCacheAge + const Duration(milliseconds: 1),
          ),
          now,
        ),
        isFalse,
      );
      expect(
        isFreshHomeLocation(now.add(const Duration(seconds: 1)), now),
        isFalse,
      );
    },
  );

  test('opens device location services when the service is disabled', () async {
    var locationSettingsCalls = 0;
    var appSettingsCalls = 0;

    final opened = await openLocationSettingsForStatus(
      serviceDisabled: true,
      openLocationServices: () async {
        locationSettingsCalls++;
        return true;
      },
      openAppPermissions: () async {
        appSettingsCalls++;
        return true;
      },
      openFallbackAppSettings: () async => true,
    );

    expect(opened, isTrue);
    expect(locationSettingsCalls, 1);
    expect(appSettingsCalls, 0);
  });

  test('falls back to app settings when a settings launcher fails', () async {
    var fallbackCalls = 0;

    final opened = await openLocationSettingsForStatus(
      serviceDisabled: true,
      openLocationServices: () async => false,
      openAppPermissions: () async => throw StateError('unavailable'),
      openFallbackAppSettings: () async {
        fallbackCalls++;
        return true;
      },
    );

    expect(opened, isTrue);
    expect(fallbackCalls, 1);
  });
}
