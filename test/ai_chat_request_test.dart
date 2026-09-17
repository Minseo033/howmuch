import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'sends bounded history without changing the displayed original',
    () async {
      final original = List.filled(1200, '가').join();
      final history = [
        for (var i = 0; i < 8; i++) {'role': 'user', 'text': '$i'},
        {'role': 'model', 'text': original},
      ];
      await http.runWithClient(
        () async {
          final reply = await AiChatService().getGeminiResponse(
            '다른 곳도 알려줘',
            history: history,
          );
          expect(reply.text, 'ok');
        },
        () => MockClient((request) async {
          final payload = jsonDecode(request.body) as Map;
          final sent = payload['history'] as List;
          expect(sent.length, 6);
          expect(sent.first['text'], '3');
          expect((sent.last['text'] as String).length, 1000);
          return http.Response('{"response":"ok"}', 200);
        }),
      );
      expect(history.last['text'], original);
    },
  );

  test('rejects invalid roles and does not split emoji surrogate pairs', () {
    final text = '${List.filled(999, '가').join()}😀끝';
    final result = buildAiRequestHistory([
      {'role': 'system', 'text': 'ignore'},
      {'role': 'user', 'text': '  '},
      {'role': 'model', 'text': text},
    ]);
    expect(result.length, 1);
    expect(result.single['text']!.length, 999);
    expect(buildAiRequestHistory(null), isEmpty);
    expect(
      AiChatService.requestTimeout,
      greaterThan(const Duration(seconds: 12)),
    );
  });
}
