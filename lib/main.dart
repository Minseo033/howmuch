import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app/howmuch_app.dart';

void main() async {
  // 💡 비동기 작업을 위해 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  // 💡 카카오 SDK 초기화
  KakaoSdk.init(nativeAppKey: '224e0cadbd6a8505be5becb3cac3fcaa');

  // 💡 디버그 콘솔에서 키 해시 확인용 (등록 후 삭제 가능)
  debugPrint("카카오 키 해시: ${await KakaoSdk.origin}");
  
  runApp(const ProviderScope(child: HowmuchApp()));
}
