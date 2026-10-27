import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'kakao_popup_code.dart';

// Native SDK already delivers typed OS/app authentication cancellation.
Future<OAuthToken> loginWithKakaoAccount() =>
    UserApi.instance.loginWithKakaoAccount();

/// Native consent runs in the SDK's own KakaoTalk/browser flow, which returns
/// when the user finishes or backs out, so no window needs to be pre-opened.
KakaoConsentRequest beginKakaoConsentRequest() => _NativeKakaoConsentRequest();

class _NativeKakaoConsentRequest implements KakaoConsentRequest {
  @override
  Future<OAuthToken> authorize(List<String> scopes) =>
      UserApi.instance.loginWithNewScopes(scopes);

  @override
  void close() {}
}
