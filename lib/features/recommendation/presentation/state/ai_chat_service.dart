import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';

final aiChatServiceProvider = Provider((ref) => AiChatService());

class AiChatService {
  /// Gemini AI 챗봇 응답 요청 (세션 인증 필요)
  Future<String> getGeminiResponse(String message) async {
    final url = ApiClient.uri('/api/ai/chat');

    try {
      final response = await http
          .post(
            url,
            headers: ApiClient.jsonHeaders(auth: true),
            body: jsonEncode({'message': message}),
          )
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['response'] ?? '응답을 이해하지 못했습니다.';
      } else if (response.statusCode == 401) {
        return '로그인이 필요한 기능입니다. 다시 로그인해주세요.';
      } else {
        return '서버 응답 에러: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('AI 챗봇 통신 에러: $e');
      return 'AI 연결에 실패했습니다. 네트워크를 확인해주세요.';
    }
  }
}