import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/startup_location.dart';
import 'package:howmuch/features/auth/presentation/screens/auth_terms_screen.dart';
import 'package:howmuch/features/auth/presentation/screens/login_screen.dart';
import 'package:howmuch/features/auth/presentation/screens/profile_setup_screen.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/auth/presentation/state/login_flow.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _Step { checkingTerms, terms, login, profile, endingSignUp }

/// Login opened on top of a screen that needs an account: the required terms
/// on a first login, Kakao login and, for a new account, profile setup.
///
/// The steps share this one screen, so the browser's back button closes the
/// whole flow instead of leaving part of it behind. The answer goes back
/// through [LoginFlowRequests].
class LoginFlowScreen extends ConsumerStatefulWidget {
  const LoginFlowScreen({super.key});

  @override
  ConsumerState<LoginFlowScreen> createState() => _LoginFlowScreenState();
}

class _LoginFlowScreenState extends ConsumerState<LoginFlowScreen> {
  late final LoginFlowRequests _requests;
  late final KakaoLoginService _loginService;
  late final bool _answersRequest;
  ScaffoldMessengerState? _messenger;

  _Step _step = _Step.checkingTerms;
  bool _loggingIn = false;
  bool _signUpPending = false;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _requests = ref.read(loginFlowRequestsProvider);
    _loginService = ref.read(kakaoLoginServiceProvider);
    _answersRequest = _requests.claim();
    _checkTerms();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    // Closed from outside, e.g. by the browser's back button.
    _answer(false);
    if (_signUpPending) unawaited(_endSignUp());
    super.dispose();
  }

  Future<void> _checkTerms() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final accepted =
        preferences.getBool(authTermsAcceptedPreferenceKey) == true;
    setState(() => _step = accepted ? _Step.login : _Step.terms);
  }

  void _answer(bool loggedIn) {
    if (_answered) return;
    _answered = true;
    if (_answersRequest) _requests.answer(loggedIn);
  }

  /// Back to the screen below, which carries on without an account.
  void _close() {
    _answer(false);
    _leave();
  }

  void _leave() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      // Opened by its address, so there is no screen below.
      context.go(ref.read(startupLocationProvider).take());
    }
  }

  /// Called straight from the button's tap: on the web the Kakao window has
  /// to open while the tap still counts as a user gesture.
  void _logInWithKakao() {
    if (_loggingIn) return;
    final attempt = _loginService.login(navigate: false);
    setState(() => _loggingIn = true);
    unawaited(_handleLogin(attempt));
  }

  Future<void> _handleLogin(Future<KakaoLoginResult> attempt) async {
    KakaoLoginResult result;
    try {
      result = await attempt;
    } catch (_) {
      result = const KakaoLoginResult(
        KakaoLoginStatus.failed,
        '잠시 후 다시 시도해 주세요.',
      );
    }
    if (!mounted || _answered) {
      _settleAfterLeaving(result);
      return;
    }
    setState(() => _loggingIn = false);
    switch (result.status) {
      case KakaoLoginStatus.cancelled:
        return;
      case KakaoLoginStatus.failed:
        _messenger?.showSnackBar(
          HowmuchSnackBar(content: Text('로그인 실패: ${result.errorMessage}')),
        );
      case KakaoLoginStatus.success when result.isNewUser:
        setState(() {
          _signUpPending = true;
          _step = _Step.profile;
        });
      case KakaoLoginStatus.success:
        _finish();
    }
  }

  /// Kakao login finished after the visitor left. A new account can't set up
  /// its profile any more, so its session ends; a member stays logged in.
  void _settleAfterLeaving(KakaoLoginResult result) {
    if (result.status != KakaoLoginStatus.success) return;
    if (result.isNewUser) {
      unawaited(_loginService.logout());
    } else {
      _messenger?.showSnackBar(HowmuchSnackBar(content: Text('카카오로 로그인했어요.')));
    }
  }

  void _finish() {
    _signUpPending = false;
    _messenger?.showSnackBar(HowmuchSnackBar(content: Text('카카오로 로그인했어요.')));
    _answer(true);
    _leave();
  }

  /// Leaving profile setup ends the new account's session, so the visitor
  /// stays a guest and can try again.
  Future<void> _leaveSignUp() async {
    if (_step != _Step.profile) return;
    setState(() => _step = _Step.endingSignUp);
    await _endSignUp();
    if (!mounted || _answered) return;
    setState(() => _step = _Step.login);
    _messenger?.showSnackBar(
      HowmuchSnackBar(content: Text('프로필을 저장해야 가입이 끝나요.')),
    );
  }

  Future<void> _endSignUp() {
    _signUpPending = false;
    return _loginService.logout();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back from profile setup returns to login; while the new session ends
      // the visitor waits.
      canPop: _step != _Step.profile && _step != _Step.endingSignUp,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _answer(false);
        } else {
          unawaited(_leaveSignUp());
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      _Step.checkingTerms || _Step.endingSignUp => const _Waiting(),
      _Step.terms => AuthTermsScreen(
        onAgreed: () => setState(() => _step = _Step.login),
        onBack: _close,
      ),
      _Step.login => LoginScreen.inFlow(
        onKakaoPressed: _logInWithKakao,
        onClose: _close,
      ),
      _Step.profile => ProfileSetupScreen(
        onSaved: _finish,
        onBack: _leaveSignUp,
      ),
    };
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: const Center(
        child: CircularProgressIndicator(color: LoginScreen.blue),
      ),
    );
  }
}
