import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';

final inquiryHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final inquiryServiceProvider = Provider(
  (ref) => InquiryService(ref.watch(inquiryHttpClientProvider)),
);

class Inquiry {
  const Inquiry({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.status,
    required this.createdAt,
    this.answer,
    this.answeredAt,
    this.imageUrls = const [],
  });

  final String id;
  final String title;
  final String content;
  final String category;
  final String status;
  final String createdAt;
  final String? answer;
  final String? answeredAt;
  final List<String> imageUrls;

  bool get isAnswered =>
      status == 'ANSWERED' || (answer?.trim().isNotEmpty ?? false);

  factory Inquiry.fromJson(Map<String, dynamic> json) {
    return Inquiry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      category: json['category']?.toString() ?? '일반',
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: json['createdAt']?.toString() ?? '',
      answer: json['answer']?.toString(),
      answeredAt: json['answeredAt']?.toString(),
      imageUrls: _stringList(json['imageUrls']),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.startsWith('https://'))
        .take(3)
        .toList(growable: false);
  }
}

class InquiryApiException implements Exception {
  const InquiryApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class InquiryService {
  InquiryService([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  /// 문의 등록 (세션 인증 필요)
  Future<Map<String, dynamic>> createInquiry({
    required String title,
    required String content,
    String? category,
    List<String> imageUrls = const [],
  }) async {
    final url = ApiClient.uri('/api/inquiry');

    try {
      final response = await _client
          .post(
            url,
            headers: ApiClient.jsonHeaders(auth: true),
            body: jsonEncode({
              'title': title,
              'content': content,
              'category': category,
              'imageUrls': imageUrls,
            }),
          )
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map) {
          return const {'error': true, 'message': '문의 등록 응답을 확인하지 못했습니다.'};
        }
        return Map<String, dynamic>.from(decoded);
      } else if (response.statusCode == 401) {
        return {
          'error': true,
          'statusCode': 401,
          'cleanupUploadedImages': true,
          'message': '로그인이 필요합니다.',
        };
      }
      return {
        'error': true,
        'statusCode': response.statusCode,
        'cleanupUploadedImages':
            response.statusCode >= 400 && response.statusCode < 500,
        'message': '문의 등록에 실패했습니다. 잠시 후 다시 시도해주세요.',
      };
    } catch (_) {
      return const {'error': true, 'message': '네트워크 연결을 확인하고 다시 시도해주세요.'};
    }
  }

  /// 내 문의 목록 조회 (세션 인증 필요)
  Future<List<Inquiry>> getMyInquiries() async {
    final url = ApiClient.uri('/api/inquiry/my');

    try {
      final response = await _client
          .get(url, headers: ApiClient.jsonHeaders(auth: true))
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! List) {
          throw const FormatException('문의 목록 응답 형식이 올바르지 않습니다.');
        }
        return decoded.map((item) {
          if (item is! Map) {
            throw const FormatException('문의 항목 형식이 올바르지 않습니다.');
          }
          return Inquiry.fromJson(Map<String, dynamic>.from(item));
        }).toList();
      }
      throw InquiryApiException(
        response.statusCode == 401 || response.statusCode == 403
            ? '문의 내역을 확인하려면 로그인이 필요합니다.'
            : '문의 내역을 불러오지 못했습니다.',
        statusCode: response.statusCode,
      );
    } on InquiryApiException {
      rethrow;
    } catch (_) {
      throw const InquiryApiException('문의 내역을 불러오지 못했습니다.');
    }
  }
}

final myInquiriesProvider = FutureProvider.autoDispose<List<Inquiry>>((ref) {
  return ref.watch(inquiryServiceProvider).getMyInquiries();
});
