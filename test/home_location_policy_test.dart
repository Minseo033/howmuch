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
}
