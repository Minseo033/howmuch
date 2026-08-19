import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../../app/app_routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import '../../../../shared/widgets/figma_mobile_canvas.dart';
import '../../store_model.dart';

class PriceHistoryScreen extends StatefulWidget {
  const PriceHistoryScreen({super.key, this.store});

  final Store? store;

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends State<PriceHistoryScreen> {
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final store = widget.store;
    final identity = store?.id.isNotEmpty == true
        ? store!.id
        : store?.storeName ?? '';
    if (identity.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage = '매장 정보가 없어 가격 이력을 불러올 수 없어요.';
      });
      return;
    }

    try {
      final response = await http
          .get(
            ApiClient.uri(
              '/api/stores/${Uri.encodeComponent(identity)}/price-history',
              store?.menu1.isNotEmpty == true ? {'menu': store!.menu1} : null,
            ),
            headers: ApiClient.jsonHeaders(),
          )
          .timeout(ApiClient.defaultTimeout);
      if (response.statusCode != 200) {
        throw Exception('가격 이력 응답 오류 ${response.statusCode}');
      }
      final decoded = jsonDecode(ApiClient.bodyText(response));
      if (decoded is! Map) throw const FormatException('응답 형식 오류');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(decoded);
        _loading = false;
      });
    } catch (error) {
      debugPrint('가격 이력 조회 오류: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '가격 이력을 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  List<Map<String, dynamic>> get _history {
    final raw = _data?['history'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _formatPrice(Object? raw) {
    final value = int.tryParse(
      raw?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '',
    );
    if (value == null) return '가격 정보 없음';
    return '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}원';
  }

  String _formatDate(Object? raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return '날짜 정보 없음';
    return '${parsed.year}.${parsed.month.toString().padLeft(2, '0')}.${parsed.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final storeName =
        _data?['storeName']?.toString() ?? store?.storeName ?? '매장 정보 없음';
    final menuName = _data?['menuName']?.toString() ?? store?.menu1 ?? '대표 메뉴';
    return FigmaMobileCanvas(
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: const CustomAppBar(title: '가격 이력'),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCurrentPriceCard(storeName, menuName),
                        const SizedBox(height: 24),
                        const Text(
                          '최근 가격 추이',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBarChart(),
                        const SizedBox(height: 24),
                        const Text(
                          '변동 이력',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildHistoryTimeline(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
        ),
        bottomNavigationBar: CustomBottomButton(
          text: '가격 변동 제보하기',
          backgroundColor: AppColors.orangeTheme,
          onPressed: () =>
              context.push(AppRoutes.priceChangeReport, extra: store),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 40,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPriceCard(String storeName, String menuName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$storeName · $menuName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                const Text(
                  '현재 등록 가격',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatPrice(_data?['currentPrice']),
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final prices = _history
        .map(
          (item) => int.tryParse(
            item['price']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '',
          ),
        )
        .whereType<int>()
        .take(12)
        .toList()
        .reversed
        .toList();
    if (prices.isEmpty) {
      return _emptyPanel('아직 승인된 가격 변동 이력이 없어요.');
    }
    final minPrice = prices.reduce((a, b) => a < b ? a : b).toDouble();
    final maxPrice = prices.reduce((a, b) => a > b ? a : b).toDouble();
    final range = (maxPrice - minPrice).clamp(1, double.infinity);
    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: prices.map((price) {
          final height = 32 + ((price - minPrice) / range) * 82;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: _formatPrice(price),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: price == maxPrice
                        ? AppColors.success
                        : AppColors.tealLight,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistoryTimeline() {
    if (_history.isEmpty) return _emptyPanel('가격 변동 이력이 표시되면 여기에 나타나요.');
    return Column(
      children: List.generate(_history.length, (index) {
        final item = _history[index];
        final isUser = item['source']?.toString() == 'USER';
        return Container(
          margin: EdgeInsets.only(
            bottom: index == _history.length - 1 ? 0 : 10,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isUser ? AppColors.orangeTheme : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatPrice(item['price']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item['description']?.toString() ??
                          (isUser ? '사용자 제보 반영' : '공공데이터 반영'),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(item['date']),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isUser ? '사용자 제보' : '공공 데이터',
                style: TextStyle(
                  color: isUser ? AppColors.orangeTheme : AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _emptyPanel(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }
}
