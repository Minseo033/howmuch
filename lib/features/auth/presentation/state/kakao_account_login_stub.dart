import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

// Native SDK already delivers typed OS/app authentication cancellation.
Future<OAuthToken> loginWithKakaoAccount() =>
    UserApi.instance.loginWithKakaoAccount();
