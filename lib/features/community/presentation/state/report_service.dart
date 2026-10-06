import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'user_report_model.dart';

/// 저장 요청의 응답을 받지 못해 서버 반영 여부를 확인하지 못했을 때 보여줄 안내입니다.
const reportSaveOutcomeUnknownMessage =
    '저장 결과를 확인하지 못했어요. 내 제보 내역에서 저장됐는지 확인한 뒤 다시 시도해주세요.';

bool isRemoteReportImage(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

/// 고른 사진 가운데 5MB 이하이면서 남은 장수 안에 드는 사진만 고릅니다.
/// 제외한 사진 수를 함께 돌려줘 화면이 이유를 알릴 수 있게 합니다.
Future<({List<XFile> accepted, int oversized, int overLimit})>
selectReportPhotos(List<XFile> picked, {required int remaining}) async {
  final accepted = <XFile>[];
  var oversized = 0;
  var overLimit = 0;
  for (final photo in picked) {
    if (await photo.length() > ReportService.maxImageBytes) {
      oversized++;
    } else if (accepted.length < remaining) {
      accepted.add(photo);
    } else {
      overLimit++;
    }
  }
  return (accepted: accepted, oversized: oversized, overLimit: overLimit);
}

/// [selectReportPhotos]에서 제외한 사진이 있을 때 보여줄 안내입니다.
String? reportPhotoSelectionNotice({
  required int oversized,
  required int overLimit,
}) {
  final notices = [
    if (oversized > 0) '5MB를 넘는 사진 $oversized장은 첨부하지 않았어요.',
    if (overLimit > 0)
      '사진은 최대 ${ReportService.maxImageCount}장까지라 $overLimit장은 제외했어요.',
  ];
  return notices.isEmpty ? null : notices.join(' ');
}

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
  final client = ApiClient.createHttpClient();
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
    request.headers.addAll(ApiClient.authHeaders(auth: true));

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

  /// 기존 제보를 수정할 때 대상 매장의 최신 메뉴와 가격을 가져옵니다.
  /// 조회에 실패하면 null을 돌려주고, 이때는 서버가 저장 시 다시 검증합니다.
  Future<Store?> fetchStore(String storeId) async {
    final normalizedId = storeId.trim();
    if (normalizedId.isEmpty) return null;
    try {
      final response = await _client
          .get(
            ApiClient.uri('/api/stores/${Uri.encodeComponent(normalizedId)}'),
            headers: ApiClient.authHeaders(),
          )
          .timeout(ApiClient.defaultTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      final store = Store.fromJson(Map<String, dynamic>.from(decoded));
      return store.id == normalizedId ? store : null;
    } catch (error) {
      debugPrint('제보 대상 매장 조회 실패: $error');
      return null;
    }
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
      return sortReportsNewestFirst(
        decoded
            .whereType<Map<String, dynamic>>()
            .map(UserReportStatus.fromJson)
            .toList(),
      );
    } catch (error) {
      debugPrint('내 제보 목록 조회 통신 에러: $error');
      return null;
    }
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

/// 서버 응답 순서와 관계없이 내 제보를 최근 작성순으로 정렬합니다.
/// 작성일을 읽을 수 없는 제보는 맨 뒤에 두고, 같은 시각이면 기존 순서를 지킵니다.
List<UserReportStatus> sortReportsNewestFirst(List<UserReportStatus> reports) {
  final entries = [
    for (var index = 0; index < reports.length; index++)
      (
        index: index,
        report: reports[index],
        createdAt: DateTime.tryParse(reports[index].createdAt),
      ),
  ];
  entries.sort((a, b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null || bTime == null) {
      if (aTime == null && bTime == null) return a.index.compareTo(b.index);
      return aTime == null ? 1 : -1;
    }
    final byTime = bTime.compareTo(aTime);
    return byTime != 0 ? byTime : a.index.compareTo(b.index);
  });
  return [for (final entry in entries) entry.report];
}

/// 응답을 받지 못한 저장 요청이 서버의 내 제보 목록에 반영됐는지 찾습니다.
///
/// 수정은 같은 ID의 제보가 보낸 내용과 같은지로 판단합니다. 새 제보는 이번에
/// 올린 사진 주소가 들어 있는 제보, 사진이 없으면 같은 매장·메뉴의 미승인
/// 제보를 저장된 것으로 봅니다.
UserReportStatus? matchSavedReport(
  List<UserReportStatus> reports,
  UserReport sent, {
  String? reportId,
}) {
  final sentMenus = [
    for (final (menu, price, free) in [
      (sent.menu1, sent.price1, sent.free1),
      (sent.menu2, sent.price2, sent.free2),
      (sent.menu3, sent.price3, sent.free3),
      (sent.menu4, sent.price4, sent.free4),
    ])
      if (menu.trim().isNotEmpty || price.trim().isNotEmpty)
        (menu.trim(), price.trim(), free),
  ];
  bool sameContent(UserReportStatus report) {
    final savedMenus = [
      for (final item in report.menuPrices)
        (item.menu.trim(), item.price.trim(), item.free),
    ];
    return report.store.trim() == sent.storeName.trim() &&
        report.changeType == (sent.changeType ?? '') &&
        listEquals(savedMenus, sentMenus) &&
        sent.imageUrls.every(report.imageUrls.contains);
  }

  if (reportId != null) {
    final report = reports.where((item) => item.id == reportId).firstOrNull;
    if (report == null || !sameContent(report)) return null;
    final description = sent.description.trim();
    if (description.isNotEmpty && report.description.trim() != description) {
      return null;
    }
    return report;
  }
  for (final report in reports) {
    final matches = sent.imageUrls.isNotEmpty
        ? sent.imageUrls.any(report.imageUrls.contains)
        : !report.isApproved && sameContent(report);
    if (matches) return report;
  }
  return null;
}

/// 한 작성 화면에서 올린 제보 사진을 기억합니다.
///
/// 저장 요청이 시간 초과로 끝나면 서버에는 이미 저장됐을 수 있으므로 사진을
/// 지우지 않고, 다시 시도할 때 같은 사진 주소를 재사용합니다.
class ReportUploadSession {
  final Map<String, String> _uploadedUrlByPath = {};

  /// 응답 없이 끝난 저장 요청이 있어 서버 반영 여부를 아직 모르는 상태입니다.
  bool saveOutcomeUnknown = false;

  /// 이미 등록된 사진 주소는 그대로 두고, 아직 올리지 않은 사진만 업로드합니다.
  Future<List<String>> resolveImageUrls(
    ReportService service,
    List<XFile> photos, {
    required bool uploadEnabled,
  }) async {
    final pending = [
      for (final photo in photos)
        if (!isRemoteReportImage(photo.path) &&
            !_uploadedUrlByPath.containsKey(photo.path))
          photo,
    ];
    if (uploadEnabled && pending.isNotEmpty) {
      final urls = await service.uploadReportImages(pending);
      for (var index = 0; index < pending.length; index++) {
        _uploadedUrlByPath[pending[index].path] = urls[index];
      }
    }
    return [
      for (final photo in photos)
        if (isRemoteReportImage(photo.path))
          photo.path
        else
          ?_uploadedUrlByPath[photo.path],
    ];
  }

  /// 서버가 저장을 거절했거나 저장 요청 전에 실패했을 때만 업로드한 사진을
  /// 정리합니다. 저장 여부를 모르는 사진은 이미 제보에 쓰였을 수 있어 남겨둡니다.
  Future<void> discardUnsaved(ReportService service) async {
    if (saveOutcomeUnknown || _uploadedUrlByPath.isEmpty) return;
    final urls = _uploadedUrlByPath.values.toList(growable: false);
    _uploadedUrlByPath.clear();
    await service.cleanupReportImages(urls);
  }

  void markSaved() {
    _uploadedUrlByPath.clear();
    saveOutcomeUnknown = false;
  }
}
