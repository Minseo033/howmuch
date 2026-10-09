import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/shared/widgets/login_required_dialog.dart';

/// How the terms, login and profile setup screens were opened.
enum LoginEntry {
  /// At app start or from onboarding. Finishing moves on to the address
  /// requested before login, otherwise home.
  startup,

  /// On top of a screen that needs an account. Finishing closes the screens
  /// with the result, so that screen can carry on with what the visitor
  /// started.
  returnToCaller,
}

LoginEntry loginEntryOf(Object? extra) =>
    extra is LoginEntry ? extra : LoginEntry.startup;

/// Opens login on top of the current screen and completes with whether the
/// visitor is logged in when they come back. A first login asks for the
/// required terms first, and a new account finishes profile setup.
Future<bool> openLoginFlow(BuildContext context) async {
  if (ApiClient.isAuthenticated) return true;
  await context.push<bool>(AppRoutes.login, extra: LoginEntry.returnToCaller);
  return ApiClient.isAuthenticated;
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
