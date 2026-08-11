import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  const AuthState({
    required this.isLoggedIn,
    required this.provider,
    required this.email,
    this.firebaseUid = '',
    this.sessionToken = '',
  });

  final bool isLoggedIn;
  final String provider;
  final String email;
  final String firebaseUid;
  final String sessionToken;

  AuthState copyWith({
    bool? isLoggedIn,
    String? provider,
    String? email,
    String? firebaseUid,
    String? sessionToken,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      provider: provider ?? this.provider,
      email: email ?? this.email,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      sessionToken: sessionToken ?? this.sessionToken,
    );
  }
}

final authStateProvider = StateProvider<AuthState>(
  (ref) => const AuthState(isLoggedIn: false, provider: '이메일', email: ''),
);
