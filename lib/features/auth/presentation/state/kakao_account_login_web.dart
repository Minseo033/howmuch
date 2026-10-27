import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:web/web.dart' as web;
import 'kakao_popup_code.dart';

/// Popup account flow for the installed Kakao SDK 1.9.5 protocol. Its public
/// AuthApi performs code retrieval/exchange and TokenManager persists success.
/// Do not log this URL: state and PKCE values belong only to this attempt.
Future<OAuthToken> loginWithKakaoAccount() async {
  final popup = _openBlankPopup();
  try {
    return await _authorizeInPopup(popup);
  } finally {
    if (!popup.closed) popup.close();
  }
}

/// Opens the consent window before any await so the user's tap still counts as
/// the popup gesture. The request then reuses the login popup protocol with the
/// SDK's agt/scope parameters and a bounded wait instead of the SDK's 10-minute
/// poll. A blocked window surfaces as POPUP_BLOCKED from [authorize].
KakaoConsentRequest beginKakaoConsentRequest() => _WebKakaoConsentRequest();

class _WebKakaoConsentRequest implements KakaoConsentRequest {
  _WebKakaoConsentRequest() : _popup = web.window.open('about:blank', '_blank');

  final web.Window? _popup;

  @override
  Future<OAuthToken> authorize(List<String> scopes) async {
    final popup = _popup;
    if (popup == null) throw _popupBlocked();
    final agt = await AuthApi.instance.agt();
    return _authorizeInPopup(
      popup,
      scopes: scopes,
      agt: agt,
      timeout: kakaoConsentPopupTimeout,
    );
  }

  @override
  void close() {
    final popup = _popup;
    if (popup != null && !popup.closed) popup.close();
  }
}

web.Window _openBlankPopup() {
  final popup = web.window.open('about:blank', '_blank');
  if (popup == null) throw _popupBlocked();
  return popup;
}

PlatformException _popupBlocked() => PlatformException(
  code: 'POPUP_BLOCKED',
  message: 'Kakao login popup could not be opened.',
);

Future<OAuthToken> _authorizeInPopup(
  web.Window popup, {
  List<String> scopes = const [],
  String? agt,
  Duration timeout = const Duration(minutes: 10),
}) async {
  final verifier = AuthCodeClient.codeVerifier();
  final state = generateRandomString(20);
  final kaHeader = await KakaoSdk.kaHeader;
  if (popup.closed) {
    throw KakaoClientException(
      ClientErrorCause.cancelled,
      'Kakao login popup was closed.',
    );
  }
  const redirectUri = CommonConstants.webAccountLoginRedirectUri;
  popup.location.href = kakaoPopupAuthorizeUri(
    clientId: KakaoSdk.appKey,
    host: KakaoSdk.hosts.kauth,
    state: state,
    verifier: verifier,
    kaHeader: kaHeader,
    scopes: scopes,
    agt: agt,
  ).toString();
  final code = await waitForKakaoPopupCode(
    isClosed: () => popup.closed,
    readCode: () =>
        AuthApi.instance.codeForWeb(stateToken: state, kaHeader: kaHeader),
    timeout: timeout,
  );
  final token = await AuthApi.instance.issueAccessToken(
    authCode: code,
    codeVerifier: verifier,
    redirectUri: redirectUri,
  );
  await TokenManagerProvider.instance.manager.setToken(token);
  return token;
}
