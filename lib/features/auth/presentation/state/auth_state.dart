import 'package:flutter_riverpod/flutter_riverpod.dart';

const kakaoProfileImagePreferenceKey = 'kakao_profile_image_url';
const kakaoEmailPreferenceKey = 'kakao_email';

String? usableAccountEmail(Object? value) {
  final email = value?.toString().trim() ?? '';
  if (email.isEmpty || email.toLowerCase() == 'unknown') return null;
  return email;
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
