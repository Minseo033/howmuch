import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app/howmuch_app.dart';

void main() async {
  // 💡 비동기 작업을 위해 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  // 💡 카카오 SDK 초기화 (웹 지원을 위해 javaScriptAppKey 추가)
  KakaoSdk.init(
    nativeAppKey: 'bea4d05b42d5c01661e2262d696f3707',
    javaScriptAppKey: '8aa42a2f5dc0314f1fe917a90aa6c112',
  );

  // 💡 디버그 콘솔에서 키 해시 확인용 (등록 후 삭제 가능)
  debugPrint("카카오 키 해시: ${await KakaoSdk.origin}");
  
  usePathUrlStrategy();
  runApp(const ProviderScope(child: HowmuchApp()));
}
