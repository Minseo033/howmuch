import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'user_report_model.dart';

final reportServiceProvider = Provider((ref) => ReportService(ref));

class ReportService {
  final Ref _ref;
  final String _backendBaseUrl = 'https://howmuch-backend-1xnu.onrender.com';

  ReportService(this._ref);

  Future<bool> submitReport(UserReport report) async {
    final url = Uri.parse('$_backendBaseUrl/api/report/store');

    try {
      debugPrint('제보 데이터 전송 시작: ${report.storeName}');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(report.toJson()),
          )
          .timeout(const Duration(seconds: 10));

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

  Future<List<UserReportStatus>?> fetchMyReports() async {
    final auth = _ref.read(authStateProvider);
    final reporterId = auth.firebaseUid.isNotEmpty
        ? auth.firebaseUid
        : auth.email;
    if (reporterId.isEmpty) return null;

    final url = Uri.parse('$_backendBaseUrl/api/report/my');

    try {
      final response = await http
          .get(url, headers: {'X-Firebase-Uid': reporterId})
          .timeout(const Duration(seconds: 10));

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
