import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app/howmuch_app.dart';
import 'features/system/presentation/state/push_notification_service.dart';

void main() {
  // 💡 비동기 작업을 위해 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  // 💡 카카오 SDK 초기화 (웹 지원을 위해 javaScriptAppKey 추가)
  KakaoSdk.init(
    nativeAppKey: 'bea4d05b42d5c01661e2262d696f3707',
    javaScriptAppKey: '8aa42a2f5dc0314f1fe917a90aa6c112',
  );

  // A registration diagnostic must not delay the first frame or run in release.
  if (kDebugMode && !kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        debugPrint("카카오 키 해시: ${await KakaoSdk.origin}");
      } catch (e) {
        debugPrint("카카오 키 해시 조회 실패(무시 가능): $e");
      }
    });
  }

  if (!kIsWeb) {
    try {
      // Register the callback without waiting for Firebase. The push service
      // initializes Firebase when needed; the background handler does so too.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('백그라운드 알림 등록 실패 (앱 정상 계속 실행): $e');
    }
  }

  usePathUrlStrategy();
  runApp(const ProviderScope(child: HowmuchApp()));
}
