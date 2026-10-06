import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingAiService extends AiChatService {
  _PendingAiService({this.fail = false});

  final bool fail;
  final replies = <Completer<AiChatReply>>[];

  @override
  Future<AiChatReply> getGeminiResponse(
    String message, {
    List<Map<String, String>>? history,
    List<String>? nearbyStoreIds,
    double? latitude,
    double? longitude,
    int radiusMeters = 3000,
  }) {
    if (fail) return Future.error(StateError('unexpected'));
    final reply = Completer<AiChatReply>();
    replies.add(reply);
    return reply.future;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HomeMapScreen.globalUserPosition = Position(
      latitude: 37.5665,
      longitude: 126.978,
      timestamp: DateTime(2026, 10, 6),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  });

  tearDown(() => HomeMapScreen.globalUserPosition = null);

  testWidgets('a reply that arrives after leaving the chat is kept', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _PendingAiService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiChatServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AiRecommendChatScreen(),
                    ),
                  ),
                  child: const Text('채팅 열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // The typing indicator spins forever, so pending states use fixed pumps
    // (route transition and scroll animation) instead of pumpAndSettle.
    Future<void> pumpFrames() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> openChat() async {
      await tester.tap(find.text('채팅 열기'));
      await pumpFrames();
    }

    Future<void> leaveChat() async {
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await pumpFrames();
    }

    const waiting = '고미가 착한가격 매장을 찾고 있어요...';
    await openChat();
    await tester.enterText(find.byType(TextField), '혼밥 분식 추천');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await pumpFrames();
    expect(find.text(waiting), findsOneWidget);
    expect(service.replies, hasLength(1));

    // Reopening while the reply is pending keeps the indicator and does not
    // allow a second question to interleave with the first answer.
    await leaveChat();
    await openChat();
    expect(find.byType(AiRecommendChatScreen), findsOneWidget);
    expect(find.text(waiting), findsOneWidget);
    await tester.enterText(find.byType(TextField), '두 번째 질문');
    await tester.pump();
    final send = tester.widget<FilledButton>(
      find.ancestor(
        of: find.byIcon(Icons.send_rounded),
        matching: find.byType(FilledButton),
      ),
    );
    expect(send.onPressed, isNull);

    await leaveChat();
    expect(find.byType(AiRecommendChatScreen), findsNothing);
    service.replies.single.complete(
      const AiChatReply(text: '근처 칼국수집을 찾았어요.'),
    );
    await pumpFrames();

    await openChat();
    expect(find.textContaining('근처 칼국수집을 찾았어요.'), findsOneWidget);
    expect(find.text(waiting), findsNothing);
    // The question bubble and the quick prompt chip share this text.
    expect(find.text('혼밥 분식 추천', skipOffstage: false), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unexpected failure answers the question and unlocks input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiChatServiceProvider.overrideWithValue(_PendingAiService(fail: true)),
        ],
        child: const MaterialApp(home: AiRecommendChatScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '근처 백반집');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('답변을 불러오지 못했어요. 잠시 후 다시 질문해주세요.'), findsOneWidget);
    expect(find.text('고미가 착한가격 매장을 찾고 있어요...'), findsNothing);
    await tester.enterText(find.byType(TextField), '다시 질문');
    await tester.pump();
    final send = tester.widget<FilledButton>(
      find.ancestor(
        of: find.byIcon(Icons.send_rounded),
        matching: find.byType(FilledButton),
      ),
    );
    expect(send.onPressed, isNotNull);
  });

  testWidgets('resetting the chat discards a reply that arrives later', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _PendingAiService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiChatServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: AiRecommendChatScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '근처 백반집');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('고미가 착한가격 매장을 찾고 있어요...'), findsOneWidget);

    await tester.tap(find.byTooltip('새 대화 시작'));
    await tester.pumpAndSettle();
    expect(find.text('고미가 착한가격 매장을 찾고 있어요...'), findsNothing);

    service.replies.single.complete(const AiChatReply(text: '늦게 온 답변'));
    await tester.pumpAndSettle();
    expect(find.textContaining('늦게 온 답변'), findsNothing);
    expect(find.text('근처 백반집'), findsNothing);
  });
}
