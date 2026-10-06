import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

/// Same authorize/PKCE parameters as the pinned SDK 1.9.5 account popup flow.
Uri kakaoPopupAuthorizeUri({
  required String clientId,
  required String state,
  required String verifier,
  required String kaHeader,
  required String host,
}) => Uri.https(host, '/oauth/authorize', {
  'client_id': clientId,
  'redirect_uri': CommonConstants.webAccountLoginRedirectUri,
  'response_type': 'code',
  'code_challenge': base64UrlEncode(
    sha256.convert(utf8.encode(verifier)).bytes,
  ).split('=').first,
  'code_challenge_method': 'S256',
  'ka': kaHeader,
  'state': state,
  'state_token': state,
  'is_popup': 'true',
});

/// SDK 1.9.5 does not observe popup closure. Own just its code-poll lifetime;
/// token retrieval, exchange and storage stay in the SDK.
/// A successful Kakao callback can auto-close the popup before its code arrives,
/// so give the single in-flight/final poll a bounded grace period.
Future<String> waitForKakaoPopupCode({
  required bool Function() isClosed,
  required Future<String> Function() readCode,
  Duration timeout = const Duration(minutes: 10),
}) {
  final result = Completer<String>();
  Timer? pollTimer;
  Timer? closeTimer;
  Timer? closeGrace;
  Timer? timeoutTimer;
  var polling = false;
  var sawClose = false;

  void cleanUp() {
    pollTimer?.cancel();
    closeTimer?.cancel();
    closeGrace?.cancel();
    timeoutTimer?.cancel();
  }

  void fail(Object error, [StackTrace? stack]) {
    if (result.isCompleted) return;
    cleanUp();
    result.completeError(error, stack);
  }

  void cancel() => fail(
    KakaoClientException(
      ClientErrorCause.cancelled,
      'Kakao login popup was closed.',
    ),
  );

  Future<void> poll() async {
    if (result.isCompleted || polling) return;
    polling = true;
    try {
      final code = await readCode();
      if (result.isCompleted) return; // a late response cannot exchange a token
      if (code.isNotEmpty && code != 'error') {
        cleanUp();
        result.complete(code);
      } else {
        // Kakao's callback may close the window just before publishing a code.
        // Keep only one GET in flight and bound this final grace by closeGrace.
        pollTimer = Timer(
          sawClose
              ? const Duration(milliseconds: 250)
              : const Duration(seconds: 1),
          poll,
        );
      }
    } catch (error, stack) {
      if (sawClose || isClosed()) {
        cancel();
      } else {
        fail(error, stack); // genuine network failure is not cancellation
      }
    } finally {
      polling = false;
    }
  }

  closeTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
    if (result.isCompleted || sawClose || !isClosed()) return;
    sawClose = true;
    pollTimer?.cancel();
    closeGrace = Timer(const Duration(seconds: 3), cancel);
    unawaited(poll());
  });
  timeoutTimer = Timer(
    timeout,
    () => fail(TimeoutException('Kakao Login timed out.')),
  );
  unawaited(poll());
  return result.future;
}
