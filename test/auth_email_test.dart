import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';

void main() {
  test('uses only meaningful account email values', () {
    expect(usableAccountEmail(null), isNull);
    expect(usableAccountEmail(''), isNull);
    expect(usableAccountEmail(' UNKNOWN '), isNull);
    expect(usableAccountEmail(' kakao@example.com '), 'kakao@example.com');
  });
}
