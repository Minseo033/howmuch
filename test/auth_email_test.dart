import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';

void main() {
  test('uses only meaningful account email values', () {
    expect(usableAccountEmail(null), isNull);
    expect(usableAccountEmail(''), isNull);
    expect(usableAccountEmail(' UNKNOWN '), isNull);
    expect(usableAccountEmail(' kakao@example.com '), 'kakao@example.com');
  });

  test('normalizes safe social profile image URLs', () {
    expect(usableProfileImageUrl(null), '');
    expect(usableProfileImageUrl('javascript:alert(1)'), '');
    expect(
      usableProfileImageUrl('http://k.kakaocdn.net/profile.jpg'),
      'https://k.kakaocdn.net/profile.jpg',
    );
    expect(
      usableProfileImageUrl('https://k.kakaocdn.net/profile.jpg'),
      'https://k.kakaocdn.net/profile.jpg',
    );
  });

  test('requests only missing Kakao identity scopes that can be consented', () {
    expect(
      missingKakaoIdentityScopes(
        emailMissing: true,
        emailNeedsAgreement: true,
        profileImageMissing: true,
        profileImageNeedsAgreement: true,
      ),
      ['account_email', 'profile_image'],
    );
  });
}
