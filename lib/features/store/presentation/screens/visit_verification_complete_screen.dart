import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:http/http.dart' as http;

class VisitVerificationCompleteScreen extends StatefulWidget {
  final int savedAmount;
  final String storeName;
  final String menu;
  final int price;

  const VisitVerificationCompleteScreen({
    super.key,
    this.savedAmount = 0,
    this.storeName = '방문 매장',
    this.menu = '',
    this.price = 0,
  });

  @override
  State<VisitVerificationCompleteScreen> createState() =>
      _VisitVerificationCompleteScreenState();
}

class _VisitVerificationCompleteScreenState
    extends State<VisitVerificationCompleteScreen> {
  int? _monthlyTotal;

  @override
  void initState() {
    super.initState();
    _fetchMonthlyTotal();
  }

  /// 이번 달 누적 절약 금액 (GET /api/savings/stats?period=this_month)
  Future<void> _fetchMonthlyTotal() async {
    try {
      final response = await http.get(
        ApiClient.uri('/api/savings/stats', {'period': 'this_month'}),
        headers: ApiClient.jsonHeaders(auth: true),
      ).timeout(ApiClient.defaultTimeout);
      if (response.statusCode == 200 && mounted) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        setState(() {
          _monthlyTotal = (data['totalSavedAmount'] as num?)?.toInt();
        });
      }
    } catch (e) {
      debugPrint('이번 달 누적 절약 조회 오류: $e');
    }
  }

  String _formatWon(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FigmaMobileCanvas(
      child: Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // 체크 아이콘
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.successSubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 50,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                '절약 금액이 기록되었어요',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '리포트에 자동으로 반영됩니다',
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              const SizedBox(height: 32),
              // 절약 금액 카드
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이번 방문 절약',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatWon(widget.savedAmount)}원',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '이번 달 누적',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          _monthlyTotal == null
                              ? '조회 중…'
                              : '${_formatWon(_monthlyTotal!)}원',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // 방문 매장 카드
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '방문 매장',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.storeName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.menu.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${widget.menu} ${_formatWon(widget.price)}원',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    context.push(AppRoutes.savingsReportDashboard);
                  },
                  child: const Text(
                    '절약 리포트 보기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text(
                    '지도에서 다른 매장 찾기',
                    style: TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
