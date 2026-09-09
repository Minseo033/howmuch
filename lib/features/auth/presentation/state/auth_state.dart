import 'package:flutter_riverpod/flutter_riverpod.dart';

const kakaoProfileImagePreferenceKey = 'kakao_profile_image_url';
const kakaoEmailPreferenceKey = 'kakao_email';

String? usableAccountEmail(Object? value) {
  final email = value?.toString().trim() ?? '';
  if (email.isEmpty || email.toLowerCase() == 'unknown') return null;
  return email;
}

String usableProfileImageUrl(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return '';
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasAuthority) return '';
  if (uri.scheme == 'https') return raw;
  if (uri.scheme == 'http') return uri.replace(scheme: 'https').toString();
  return '';
}

List<String> missingKakaoIdentityScopes({
  required bool emailMissing,
  required bool emailNeedsAgreement,
  required bool profileImageMissing,
  required bool profileImageNeedsAgreement,
  required bool legacyProfileNeedsAgreement,
}) {
  return [
    if (emailMissing && emailNeedsAgreement) 'account_email',
    if (profileImageMissing && legacyProfileNeedsAgreement)
      'profile'
    else if (profileImageMissing && profileImageNeedsAgreement)
      'profile_image',
  ];
}

class AuthState {
  const AuthState({
    required this.isLoggedIn,
    required this.provider,
    required this.email,
    this.firebaseUid = '',
    this.sessionToken = '',
    this.profileImageUrl = '',
  });

  final bool isLoggedIn;
  final String provider;
  final String email;
  final String firebaseUid;
  final String sessionToken;
  final String profileImageUrl;

  AuthState copyWith({
    bool? isLoggedIn,
    String? provider,
    String? email,
    String? firebaseUid,
    String? sessionToken,
    String? profileImageUrl,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      provider: provider ?? this.provider,
      email: email ?? this.email,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      sessionToken: sessionToken ?? this.sessionToken,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}

final authStateProvider = StateProvider<AuthState>(
  (ref) => const AuthState(isLoggedIn: false, provider: '', email: ''),
);
