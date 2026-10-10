import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/startup_location.dart';
import 'package:howmuch/core/network/api_client.dart';
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
  bool _answered = false;
  bool _leaveWhenOnTop = false;

  /// A new account is logged in but its profile isn't saved yet.
  bool _signUpPending = false;
  Future<bool>? _profileSave;
  bool? _profileSaved;

  bool get _savingProfile => _profileSave != null && _profileSaved == null;

  @override
  void initState() {
    super.initState();
    _requests = ref.read(loginFlowRequestsProvider);
    _loginService = ref.read(kakaoLoginServiceProvider);
    _answersRequest = _requests.claim();
    if (!_answersRequest && ApiClient.isAuthenticated) {
      // Reopened from browser history after the visitor logged in.
      _answered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
      return;
    }
    _checkTerms();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
    // Depending on the route runs this again once the flow is back on top.
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    if (_leaveWhenOnTop && onTop) {
      _leaveWhenOnTop = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
    }
  }

  @override
  void dispose() {
    // Closed from outside, e.g. by the browser's back button.
    _answer(false);
    if (_signUpPending) _endSignUpUnlessSaved();
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

  /// Closes the flow. Its browser history entry is replaced rather than
  /// followed by a new one, so the back button doesn't reopen login.
  void _leave() {
    if (!mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      // Something opened above the flow, e.g. a notice right after login.
      _leaveWhenOnTop = true;
      return;
    }
    void close() {
      if (context.canPop()) {
        context.pop();
      } else {
        // Opened by its address, so there is no screen below.
        context.go(ref.read(startupLocationProvider).take());
      }
    }

    if (Router.maybeOf(context) != null) {
      Router.neglect(context, close);
    } else {
      close();
    }
  }

  /// Called straight from the button's tap: on the web the Kakao window has
  /// to open while the tap still counts as a user gesture.
  void _logInWithKakao() {
    if (_loggingIn) return;
    final attempt = _loginService.login(navigate: false);
    // Joining a login that a screen the visitor left is still running takes
    // its result over.
    _requests.kakaoLoginOwner = this;
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
    final ownsResult = identical(_requests.kakaoLoginOwner, this);
    if (ownsResult) _requests.kakaoLoginOwner = null;
    if (!mounted || _answered) {
      if (ownsResult) _settleAfterLeaving(result);
      return;
    }
    setState(() => _loggingIn = false);
    if (!ownsResult) return;
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
  /// its profile any more, so its sign-up ends; a member stays logged in.
  void _settleAfterLeaving(KakaoLoginResult result) {
    if (result.status != KakaoLoginStatus.success) return;
    if (result.isNewUser) {
      unawaited(_loginService.endUnfinishedSignUp());
    } else {
      _notify('카카오로 로그인했어요.');
    }
  }

  void _finish() {
    if (_answered || _step == _Step.endingSignUp) return;
    _signUpPending = false;
    _notify('카카오로 로그인했어요.');
    _answer(true);
    _leave();
  }

  void _onProfileSaving(Future<bool> save) {
    _profileSave = save;
    _profileSaved = null;
    void settle(bool saved) {
      if (identical(_profileSave, save)) _profileSaved = saved;
    }

    unawaited(save.then(settle, onError: (Object _) => settle(false)));
  }

  /// Leaving profile setup ends the new account's session, so the visitor
  /// stays a guest and can try again. Nothing happens while the profile
  /// saves, and a stored profile finishes sign-up instead.
  Future<void> _leaveSignUp() async {
    if (_step != _Step.profile || _savingProfile) return;
    if (_profileSaved == true) {
      _finish();
      return;
    }
    _signUpPending = false;
    setState(() => _step = _Step.endingSignUp);
    await _loginService.endUnfinishedSignUp();
    if (!mounted || _answered) return;
    setState(() => _step = _Step.login);
    _notify('프로필을 저장해야 가입이 끝나요.');
  }

  /// The flow closed before sign-up finished. A profile the server stored
  /// keeps the new member logged in; otherwise the session ends.
  void _endSignUpUnlessSaved() {
    _signUpPending = false;
    final save = _profileSave;
    if (_profileSaved == true) return;
    if (save == null || _profileSaved == false) {
      unawaited(_loginService.endUnfinishedSignUp());
      return;
    }
    unawaited(
      save.then<void>((saved) async {
        if (saved) {
          _notify('가입을 마쳤어요.');
        } else {
          await _loginService.endUnfinishedSignUp();
        }
      }, onError: (Object _) => _loginService.endUnfinishedSignUp()),
    );
  }

  void _notify(String message) {
    final messenger = _messenger;
    if (messenger == null || !messenger.mounted) return;
    messenger.showSnackBar(HowmuchSnackBar(content: Text(message)));
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
      child: KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
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
        onSaving: _onProfileSaving,
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
