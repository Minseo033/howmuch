import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'user_report_model.dart';

final reportServiceProvider = Provider((ref) => ReportService(ref));

class ReportService {
  final Ref _ref;

  ReportService(this._ref);

  /// 가성비 매장 제보 등록 (세션 인증 필요, 제보자 uid는 서버가 세션에서 주입)
  Future<bool> submitReport(UserReport report) async {
    final url = ApiClient.uri('/api/report/store');

    try {
      debugPrint('제보 데이터 전송 시작: ${report.storeName}');
      final response = await http
          .post(
            url,
            headers: ApiClient.jsonHeaders(auth: true),
            body: jsonEncode(report.toJson()),
          )
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('제보 성공: ${data['reportId']}');
        return true;
      } else {
        debugPrint('제보 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('제보 통신 에러: $e');
      return false;
    }
  }

  /// 내 제보 내역 조회 (세션 인증 필요)
  Future<List<UserReportStatus>?> fetchMyReports() async {
    if (!ApiClient.isAuthenticated) {
      debugPrint('내 제보 목록 조회: 로그인 세션 없음');
      return null;
    }

    final url = ApiClient.uri('/api/report/my');

    try {
      final response = await http
          .get(url, headers: ApiClient.jsonHeaders(auth: true))
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode != 200) {
        debugPrint('내 제보 목록 조회 실패: ${response.statusCode} ${response.body}');
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return null;

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(UserReportStatus.fromJson)
          .toList();
    } catch (e) {
      debugPrint('내 제보 목록 조회 통신 에러: $e');
      return null;
    }
  }
}