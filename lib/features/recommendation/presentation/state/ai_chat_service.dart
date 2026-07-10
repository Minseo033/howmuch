import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/app/backend_config.dart';

final aiChatServiceProvider = Provider((ref) => AiChatService());

class AiChatService {
  Future<String> getGeminiResponse(String message) async {
    final url = Uri.parse('${BackendConfig.baseUrl}/api/ai/chat');

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['response'] ?? '응답을 이해하지 못했습니다.';
      } else {
        return '서버 응답 에러: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('AI 챗봇 통신 에러: $e');
      return 'AI 연결에 실패했습니다. 네트워크를 확인해주세요.';
    }
  }
}
