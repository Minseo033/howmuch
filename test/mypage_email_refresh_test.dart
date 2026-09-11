import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';

void main() {
  group('Mypage email resolution and refresh policy', () {
    test('missing or unknown email triggers refresh eligibility', () {
      expect(usableAccountEmail(null), isNull);
      expect(usableAccountEmail(''), isNull);
      expect(usableAccountEmail('unknown'), isNull);
      expect(usableAccountEmail('UNKNOWN'), isNull);
      expect(usableAccountEmail('test@example.com'), 'test@example.com');
    });

    test('valid email is correctly preserved', () {
      final valid = usableAccountEmail('user@kakao.com');
      expect(valid, 'user@kakao.com');
    });
  });
}
