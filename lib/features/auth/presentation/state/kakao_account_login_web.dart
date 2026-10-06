import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:web/web.dart' as web;
import 'kakao_popup_code.dart';

/// Popup account flow for the installed Kakao SDK 1.9.5 protocol. Its public
/// AuthApi performs code retrieval/exchange and TokenManager persists success.
/// Do not log this URL: state and PKCE values belong only to this attempt.
Future<OAuthToken> loginWithKakaoAccount() async {
  final popup = web.window.open('about:blank', '_blank');
  if (popup == null) {
    throw PlatformException(
      code: 'POPUP_BLOCKED',
      message: 'Kakao login popup could not be opened.',
    );
  }
  try {
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
    ).toString();
    final code = await waitForKakaoPopupCode(
      isClosed: () => popup.closed,
      readCode: () =>
          AuthApi.instance.codeForWeb(stateToken: state, kaHeader: kaHeader),
    );
    final token = await AuthApi.instance.issueAccessToken(
      authCode: code,
      codeVerifier: verifier,
      redirectUri: redirectUri,
    );
    await TokenManagerProvider.instance.manager.setToken(token);
    return token;
  } finally {
    if (!popup.closed) popup.close();
  }
}
