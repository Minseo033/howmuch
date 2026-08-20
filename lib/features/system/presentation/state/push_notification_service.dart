import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/app/app_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/system/presentation/state/notification_service.dart';
import 'package:http/http.dart' as http;

const _notificationChannel = AndroidNotificationChannel(
  'howmuch_notifications',
  '얼마고 알림',
  description: '문의 답변, 가격 변동, 제보 처리 알림',
  importance: Importance.high,
);

/// FCM background handlers must stay top-level so the native runtime can call
/// them when Flutter is not already running.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;
  final http.Client _client = http.Client();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  Future<bool>? _startup;
  bool _isRegistered = false;
  String? _registeredToken;

  Future<bool> start() {
    if (kIsWeb || !_supportsPush) return Future.value(false);
    return _startup ??= _start();
  }

  Future<void> registerForCurrentSession() async {
    try {
      if (!await start()) return;

      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (!_canShowNotifications(permission)) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
    } catch (_) {
      // FCM 설정 파일이 아직 없거나 네트워크가 잠시 불안정해도 로그인은 유지합니다.
      debugPrint('FCM 기기 등록을 완료하지 못했습니다.');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (!_isRegistered || _registeredToken == null) return;

    try {
      await _client
          .delete(
            ApiClient.uri('/api/notifications/devices'),
            headers: ApiClient.jsonHeaders(auth: true),
            body: jsonEncode({
              'token': _registeredToken,
              'platform': _platformName,
            }),
          )
          .timeout(ApiClient.defaultTimeout);
    } catch (_) {
      // A future login refreshes the token. Logout must not be blocked by a
      // transient network failure while removing this device registration.
    } finally {
      _isRegistered = false;
      _registeredToken = null;
    }
  }

  Future<bool> _start() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      await _initializeLocalNotifications();
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (_) => _openNotificationInbox(),
      );
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen(_registerToken);

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _openNotificationInbox();
      }
      return true;
    } catch (_) {
      debugPrint('FCM 초기화를 완료하지 못했습니다.');
      return false;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (_) => _openNotificationInbox(),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_notificationChannel);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _ref
        .read(notificationsProvider.notifier)
        .loadNotifications(isRefresh: true);

    if (defaultTargetPlatform != TargetPlatform.android) return;
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title']?.toString() ?? '얼마고';
    final body = notification?.body ?? message.data['body']?.toString() ?? '';
    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'howmuch_notifications',
          '얼마고 알림',
          channelDescription: '문의 답변, 가격 변동, 제보 처리 알림',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        ),
      ),
    );
  }

  Future<void> _registerToken(String token) async {
    if (token.isEmpty || !_supportsPush) return;

    try {
      final response = await _client
          .post(
            ApiClient.uri('/api/notifications/devices'),
            headers: ApiClient.jsonHeaders(auth: true),
            body: jsonEncode({'token': token, 'platform': _platformName}),
          )
          .timeout(ApiClient.defaultTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _registeredToken = token;
        _isRegistered = true;
      } else {
        debugPrint('FCM 토큰 등록 실패: ${response.statusCode}');
      }
    } catch (_) {
      debugPrint('FCM 토큰 등록을 완료하지 못했습니다.');
    }
  }

  void _openNotificationInbox() {
    _ref.read(appRouterProvider).go(AppRoutes.notifications);
  }

  bool get _supportsPush =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  String get _platformName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  bool _canShowNotifications(NotificationSettings settings) {
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _client.close();
  }
}
