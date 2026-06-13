import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'user_report_model.dart';

final reportServiceProvider = Provider((ref) => ReportService(ref));

class ReportService {
  final Ref _ref;
  final String _backendHost = kIsWeb ? 'localhost' : '192.168.0.13';

  ReportService(this._ref);

  Future<bool> submitReport(UserReport report) async {
    final url = Uri.parse('http://$_backendHost:8081/api/report/store');

    try {
      debugPrint('제보 데이터 전송 시작: ${report.storeName}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(report.toJson()),
      ).timeout(const Duration(seconds: 10));

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
}
