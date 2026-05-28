import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  const AuthState({
    required this.isLoggedIn,
    required this.provider,
    required this.email,
  });

  final bool isLoggedIn;
  final String provider;
  final String email;

  AuthState copyWith({bool? isLoggedIn, String? provider, String? email}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      provider: provider ?? this.provider,
      email: email ?? this.email,
    );
  }
}

final authStateProvider = StateProvider<AuthState>(
  (ref) => const AuthState(
    isLoggedIn: false,
    provider: '이메일',
    email: 'minseo@example.com',
  ),
);
