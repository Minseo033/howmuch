import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';

final inquiryServiceProvider = Provider((ref) => InquiryService());

class InquiryService {
  /// 문의 등록 (세션 인증 필요)
  Future<Map<String, dynamic>> createInquiry({
    required String title,
    required String content,
    String? category,
  }) async {
    final url = ApiClient.uri('/api/inquiry');

    try {
      final response = await http
          .post(
            url,
            headers: ApiClient.jsonHeaders(auth: true),
            body: jsonEncode({
              'title': title,
              'content': content,
              if (category != null) 'category': category,
            }),
          )
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else if (response.statusCode == 401) {
        return {'error': true, 'statusCode': 401, 'message': '로그인이 필요합니다.'};
      }
      debugPrint('문의 등록 API 에러: ${response.statusCode}');
      return {'error': true, 'statusCode': response.statusCode};
    } catch (e) {
      debugPrint('문의 등록 통신 에러: $e');
      return {'error': true, 'message': e.toString()};
    }
  }

  /// 내 문의 목록 조회 (세션 인증 필요)
  Future<List<dynamic>> getMyInquiries() async {
    final url = ApiClient.uri('/api/inquiry/my');

    try {
      final response = await http
          .get(url, headers: ApiClient.jsonHeaders(auth: true))
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      debugPrint('내 문의 목록 API 에러: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('내 문의 목록 통신 에러: $e');
      return [];
    }
  }
}
