import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  const AuthState({
    required this.isLoggedIn,
    required this.isAdmin,
    required this.provider,
    required this.email,
  });

  final bool isLoggedIn;
  final bool isAdmin;
  final String provider;
  final String email;

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isAdmin,
    String? provider,
    String? email,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isAdmin: isAdmin ?? this.isAdmin,
      provider: provider ?? this.provider,
      email: email ?? this.email,
    );
  }
}

final authStateProvider = StateProvider<AuthState>(
  (ref) => const AuthState(
    isLoggedIn: false,
    isAdmin: false,
    provider: '이메일',
    email: 'minseo@example.com',
  ),
);
