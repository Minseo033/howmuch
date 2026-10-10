import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/shared/widgets/login_required_dialog.dart';

/// Carries the answer of the login screens back to the screen that opened
/// them.
///
/// A route result can't do this on the web: when the browser goes back,
/// go_router rebuilds the screens from its saved history, and the result of a
/// screen opened before never arrives.
class LoginFlowRequests {
  Completer<bool>? _open;
  bool _claimed = false;

  /// The login screen that handles the result of the Kakao login that is
  /// running. A screen that joins a running login takes it over from one the
  /// visitor left.
  Object? kakaoLoginOwner;

  /// Opens the login screens with [openScreens] and completes with the
  /// answer. A second call while they are open waits for the same answer.
  Future<bool> start(Future<void> Function() openScreens) {
    final open = _open;
    if (open != null) return open.future;
    final request = Completer<bool>();
    _open = request;
    _claimed = false;
    unawaited(
      Future<void>.sync(
        openScreens,
      ).then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
        // Closed before the login screens ever opened.
        if (identical(_open, request) && !_claimed) answer(false);
      }),
    );
    return request.future;
  }

  /// Taken once by the login screens when they open. False for screens that
  /// nothing waits for, such as ones the browser's forward button reopened.
  bool claim() {
    if (_open == null || _claimed) return false;
    _claimed = true;
    return true;
  }

  /// Answers the open request. Later answers are ignored.
  void answer(bool loggedIn) {
    final request = _open;
    _open = null;
    _claimed = false;
    if (request != null && !request.isCompleted) request.complete(loggedIn);
  }
}

final loginFlowRequestsProvider = Provider((ref) => LoginFlowRequests());

/// Opens login on top of the current screen and completes with whether the
/// visitor is logged in when they come back. A first login asks for the
/// required terms first, and a new account finishes profile setup.
Future<bool> openLoginFlow(BuildContext context) async {
  if (ApiClient.isAuthenticated) return true;
  final requests = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(loginFlowRequestsProvider);
  final router = GoRouter.of(context);
  final loggedIn = await requests.start(
    () => router.push<void>(AppRoutes.loginFlow),
  );
  return loggedIn && ApiClient.isAuthenticated;
}

/// Tells a guest why [message] needs an account and, if they choose to log
/// in, opens login on top of the current screen. Completes with whether the
/// visitor is logged in, so the caller can finish the action it started.
Future<bool> requireLogin(
  BuildContext context, {
  required String message,
}) async {
  if (ApiClient.isAuthenticated) return true;
  final shouldLogin = await showLoginRequiredDialog(context, message: message);
  if (!shouldLogin || !context.mounted) return false;
  return openLoginFlow(context);
}
