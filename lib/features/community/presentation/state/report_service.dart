import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'user_report_model.dart';

class ReportServiceException implements Exception {
  const ReportServiceException(
    this.message, {
    this.statusCode,
    this.cleanupUploadedImages = false,
  });

  final String message;
  final int? statusCode;
  final bool cleanupUploadedImages;

  @override
  String toString() => message;
}

final reportServiceProvider = Provider<ReportService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ReportService(client);
});

class ReportService {
  ReportService(this._client);

  static const maxImageCount = 3;
  static const maxImageBytes = 5 * 1024 * 1024;
  static const _uploadTimeout = Duration(seconds: 60);

  final http.Client _client;

  Future<List<String>> uploadReportImages(List<XFile> images) async {
    if (images.isEmpty) return const [];
    _requireAuthentication();
    if (images.length > maxImageCount) {
      throw const ReportServiceException('사진은 최대 3장까지 첨부할 수 있습니다.');
    }

    final request = http.MultipartRequest(
      'POST',
      ApiClient.uri('/api/report/images'),
    );
    request.headers.addAll(_authHeaders());

    for (var index = 0; index < images.length; index++) {
      final bytes = await images[index].readAsBytes();
      if (bytes.isEmpty) {
        throw const ReportServiceException('비어 있는 사진은 첨부할 수 없습니다.');
      }
      if (bytes.length > maxImageBytes) {
        throw const ReportServiceException('사진 한 장의 용량은 5MB 이하여야 합니다.');
      }

      final imageType = _detectImageType(bytes);
      if (imageType == null) {
        throw const ReportServiceException(
          'JPEG, PNG, WebP 형식의 사진만 첨부할 수 있습니다.',
        );
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: 'report-image-${index + 1}.${imageType.extension}',
          contentType: MediaType.parse(imageType.mimeType),
        ),
      );
    }

    final streamed = await _client.send(request).timeout(_uploadTimeout);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw ReportServiceException(
        _responseMessage(
          body,
          fallback: '사진 업로드에 실패했습니다.',
          allowServerMessage: streamed.statusCode == 400,
        ),
        statusCode: streamed.statusCode,
        cleanupUploadedImages: true,
      );
    }

    final decoded = jsonDecode(body);
    final urls = decoded is Map<String, dynamic> ? decoded['imageUrls'] : null;
    if (urls is! List || urls.length != images.length) {
      throw const FormatException('사진 업로드 응답 형식이 올바르지 않습니다.');
    }
    return urls.map((url) => url.toString()).toList(growable: false);
  }

  Future<void> cleanupReportImages(List<String> imageUrls) async {
    if (imageUrls.isEmpty || !ApiClient.isAuthenticated) return;
    try {
      await _client
          .post(
            ApiClient.uri('/api/report/images/cleanup'),
            headers: ApiClient.jsonHeaders(auth: true),
            body: jsonEncode({'imageUrls': imageUrls}),
          )
          .timeout(ApiClient.defaultTimeout);
    } catch (error) {
      debugPrint('사용되지 않은 제보 사진 정리 실패: $error');
    }
  }

  Future<String> submitReport(UserReport report) async {
    final response = await _saveReport(
      method: 'POST',
      path: '/api/report/store',
      report: report,
    );
    final reportId = response['reportId']?.toString();
    if (reportId == null || reportId.isEmpty) {
      throw const FormatException('제보 등록 응답에 식별자가 없습니다.');
    }
    return reportId;
  }

  Future<void> updateReport(String reportId, UserReport report) async {
    if (reportId.trim().isEmpty) {
      throw const ReportServiceException('수정할 제보를 찾을 수 없습니다.');
    }
    await _saveReport(
      method: 'PUT',
      path: '/api/report/store/$reportId',
      report: report,
    );
  }

  Future<int> deleteReport(String reportId) async {
    final normalizedId = reportId.trim();
    if (normalizedId.isEmpty) {
      throw const ReportServiceException('삭제할 제보를 찾을 수 없습니다.');
    }
    _requireAuthentication();

    final response = await _client
        .delete(
          ApiClient.uri(
            '/api/report/store/${Uri.encodeComponent(normalizedId)}',
          ),
          headers: ApiClient.jsonHeaders(auth: true),
        )
        .timeout(ApiClient.defaultTimeout);
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw ReportServiceException(
        _responseMessage(
          body,
          fallback: '제보 삭제에 실패했습니다.',
          allowServerMessage:
              response.statusCode == 403 ||
              response.statusCode == 404 ||
              response.statusCode == 409 ||
              response.statusCode == 503,
        ),
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['success'] != true) {
      throw const FormatException('제보 삭제 응답 형식이 올바르지 않습니다.');
    }
    final deletedImages = decoded['deletedImages'];
    return deletedImages is num ? deletedImages.toInt() : 0;
  }

  Future<Map<String, dynamic>> _saveReport({
    required String method,
    required String path,
    required UserReport report,
  }) async {
    _requireAuthentication();
    final request = http.Request(method, ApiClient.uri(path))
      ..headers.addAll(ApiClient.jsonHeaders(auth: true))
      ..body = jsonEncode(report.toJson());
    final streamed = await _client
        .send(request)
        .timeout(ApiClient.defaultTimeout);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw ReportServiceException(
        _responseMessage(
          body,
          fallback: method == 'POST' ? '제보 제출에 실패했습니다.' : '제보 수정에 실패했습니다.',
          allowServerMessage:
              streamed.statusCode == 400 ||
              streamed.statusCode == 403 ||
              streamed.statusCode == 404 ||
              streamed.statusCode == 409,
        ),
        statusCode: streamed.statusCode,
        cleanupUploadedImages: true,
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('제보 저장 응답 형식이 올바르지 않습니다.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<List<UserReportStatus>?> fetchMyReports() async {
    if (!ApiClient.isAuthenticated) {
      debugPrint('내 제보 목록 조회: 로그인 세션 없음');
      return null;
    }

    try {
      final response = await _client
          .get(
            ApiClient.uri('/api/report/my'),
            headers: ApiClient.jsonHeaders(auth: true),
          )
          .timeout(ApiClient.defaultTimeout);
      if (response.statusCode != 200) {
        debugPrint('내 제보 목록 조회 실패: ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(UserReportStatus.fromJson)
          .toList();
    } catch (error) {
      debugPrint('내 제보 목록 조회 통신 에러: $error');
      return null;
    }
  }

  Map<String, String> _authHeaders() {
    final token = ApiClient.sessionToken!;
    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  void _requireAuthentication() {
    if (!ApiClient.isAuthenticated) {
      throw const ReportServiceException(
        '제보 기능을 사용하려면 로그인이 필요합니다.',
        statusCode: 401,
      );
    }
  }

  String _responseMessage(
    String body, {
    required String fallback,
    required bool allowServerMessage,
  }) {
    if (!allowServerMessage) return fallback;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        final message = (decoded['message'] as String).trim();
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}
    return fallback;
  }

  _ReportImageType? _detectImageType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return const _ReportImageType('image/jpeg', 'jpg');
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return const _ReportImageType('image/png', 'png');
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return const _ReportImageType('image/webp', 'webp');
    }
    return null;
  }
}

class _ReportImageType {
  const _ReportImageType(this.mimeType, this.extension);

  final String mimeType;
  final String extension;
}
