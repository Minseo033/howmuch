import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/figma_mobile_canvas.dart';

abstract class _Colors {
  static const backgroundDark = Color(0xFFF8FAFC);
  static const muted = Color(0xFF64748B);
  static const black = Color(0xFF0F172A);
  static const primary = Color(0xFF2563EB);
  static const primarySubtle = Color(0xFFEFF6FF);
  static const orangeTheme = Color(0xFFF97316);
  static const orangeLight = Color(0xFFFFF7ED);
  static const success = Color(0xFF16A34A);
  static const successSubtle = Color(0xFFF0FDF4);
  static const white = Colors.white;
}

String? formatVisitVerification(String? method, double? distanceMeters) {
  if (method == 'LOCATION' && distanceMeters != null) {
    return '위치 인증 · ${distanceMeters.round()}m';
  }
  if (method == 'RECEIPT_OCR') return '영수증 OCR 인증';
  return null;
}

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _visits = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(
            ApiClient.uri('/api/visits'),
            headers: ApiClient.jsonHeaders(auth: true),
          )
          .timeout(ApiClient.defaultTimeout);

      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final parsed = data.map((item) {
          final isGov = item['isGov'] == true;
          final savedAmt = (item['savedAmount'] as num?)?.toInt() ?? 0;
          final priceAmt = (item['price'] as num?)?.toInt() ?? 0;
          final verificationMethod = item['verificationMethod']?.toString();
          final verificationDistance =
              (item['verificationDistanceMeters'] as num?)?.toDouble();
          final dateStr = _formatDate(item['visitedAt']?.toString());

          return {
            'isGov': isGov,
            'name': item['storeName'] ?? '미등록 매장',
            'menu': item['menu'] ?? '일반 방문',
            'price': priceAmt > 0
                ? '${_formatCurrency(priceAmt)}원'
                : '가격 정보 없음',
            'savedAmount': savedAmt,
            'saving': '${_formatCurrency(savedAmt)}원 절약',
            'date': dateStr,
            'verification': formatVisitVerification(
              verificationMethod,
              verificationDistance,
            ),
            'icon': isGov ? Icons.smart_toy_rounded : Icons.local_cafe_rounded,
          };
        }).toList();

        setState(() {
          _visits = parsed;
          _isLoading = false;
        });
      } else {
        _showFetchError(
          response.statusCode == 401
              ? '로그인 후 방문 기록을 확인할 수 있어요.'
              : '방문 기록을 불러오지 못했어요.',
        );
      }
    } catch (e) {
      _showFetchError('네트워크 상태를 확인한 뒤 다시 시도해주세요.');
    }
  }

  void _showFetchError(String message) {
    setState(() {
      _visits = [];
      _errorMessage = message;
      _isLoading = false;
    });
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '최근 방문';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y.$m.$d';
    } catch (_) {
      return rawDate;
    }
  }

  int get _totalSavedAmount {
    return _visits.fold(
      0,
      (sum, item) => sum + ((item['savedAmount'] as int?) ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FigmaMobileCanvas(
      backgroundColor: _Colors.backgroundDark,
      child: Scaffold(
        backgroundColor: _Colors.backgroundDark,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: AppBar(
            backgroundColor: _Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _Colors.black,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              '방문 기록',
              style: TextStyle(
                color: _Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: RichText(
                    text: TextSpan(
                      text: '총 ',
                      style: const TextStyle(
                        color: _Colors.muted,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: '${_visits.length}',
                          style: const TextStyle(
                            color: _Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(text: '회'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _Colors.primary),
                )
              : RefreshIndicator(
                  onRefresh: _fetchVisits,
                  color: _Colors.primary,
                  child: Column(
                    children: [
                      _buildSummaryCard(),
                      Expanded(
                        child: _errorMessage != null
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 88),
                                  const Icon(
                                    Icons.cloud_off_rounded,
                                    color: _Colors.muted,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: _Colors.muted,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: OutlinedButton(
                                      onPressed: _fetchVisits,
                                      child: const Text('다시 시도'),
                                    ),
                                  ),
                                ],
                              )
                            : _visits.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 100),
                                  Center(
                                    child: Text(
                                      '아직 방문 기록이 없습니다.',
                                      style: TextStyle(
                                        color: _Colors.muted,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                itemCount: _visits.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) =>
                                    _buildVisitCard(_visits[index]),
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: _Colors.successSubtle,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  '${_visits.length}',
                  style: const TextStyle(
                    color: _Colors.success,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '이번 달 방문',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 44, color: Colors.green.shade200),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${_formatCurrency(_totalSavedAmount)}원',
                  style: const TextStyle(
                    color: _Colors.success,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '이번 달 절약',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> item) {
    final isGov = item['isGov'] as bool;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // 아이콘
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isGov ? _Colors.primarySubtle : _Colors.orangeLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: isGov ? _Colors.primary : _Colors.orangeTheme,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 배지 + 이름 + 날짜
                Row(
                  children: [
                    _VisitBadge(isGov: isGov),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      item['date'] as String,
                      style: const TextStyle(
                        color: _Colors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // 메뉴 · 가격
                Text(
                  '${item['menu']} · ${item['price']}',
                  style: const TextStyle(color: _Colors.muted, fontSize: 13),
                ),
                if (item['verification'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item['verification'] as String,
                    style: const TextStyle(
                      color: _Colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // 절약 금액
                Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      item['saving'] as String,
                      style: const TextStyle(
                        color: _Colors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitBadge extends StatelessWidget {
  final bool isGov;
  const _VisitBadge({required this.isGov});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isGov ? _Colors.primarySubtle : _Colors.orangeLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isGov ? '정부인증' : '사용자제보',
        style: TextStyle(
          color: isGov ? _Colors.primary : _Colors.orangeTheme,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
