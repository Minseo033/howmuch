import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'dart:convert';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/savings/presentation/state/savings_period.dart';
import 'package:howmuch/app/app_routes.dart';

@visibleForTesting
String normalizeSavingsCategory(Object? rawValue) {
  final value = rawValue?.toString().trim() ?? '';
  if (value.isEmpty) return '기타';
  if (value.contains('카페') ||
      value.contains('커피') ||
      value.contains('다방') ||
      value.contains('제과') ||
      value.contains('베이커리')) {
    return '카페';
  }
  if (value.contains('미용') || value.contains('이용') || value.contains('헤어')) {
    return '미용';
  }
  // The public dataset has '기타비요식업' (non-food) next to '기타요식업' (food).
  if (value.contains('비요식')) return '기타';
  if (value.contains('음식') ||
      value.contains('식당') ||
      value.contains('분식') ||
      value.contains('한식') ||
      value.contains('중식') ||
      value.contains('양식') ||
      value.contains('일식') ||
      value.contains('요식')) {
    return '음식점';
  }
  return '기타';
}

class SavingsDetailItem {
  final String category; // '음식점', '카페', '미용'
  final String badgeText;
  final Color badgeColor;
  final Color badgeBg;
  final String date;
  final DateTime? dateValue;
  final String storeName;
  final String menuName;
  final String price;
  final String savingAmount;
  final int savedAmountValue;

  SavingsDetailItem({
    required this.category,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeBg,
    required this.date,
    required this.dateValue,
    required this.storeName,
    required this.menuName,
    required this.price,
    required this.savingAmount,
    required this.savedAmountValue,
  });
}

class SavingsDetailScreen extends StatefulWidget {
  const SavingsDetailScreen({super.key, this.startDate, this.endDateExclusive});

  final String? startDate;
  final String? endDateExclusive;

  @override
  State<SavingsDetailScreen> createState() => _SavingsDetailScreenState();
}

class _SavingsDetailScreenState extends State<SavingsDetailScreen> {
  String _selectedFilter = '전체';
  bool _isLoading = false;
  String? _errorMessage;
  List<SavingsDetailItem> _allItems = [];
  int _totalSavedAmount = 0;
  int _visitCount = 0;
  int _averageSaved = 0;
  late final SavingsPeriod? _period;

  List<String> get _availableCategories {
    const preferredOrder = ['음식점', '카페', '미용', '기타'];
    final present = _allItems.map((item) => item.category).toSet();
    return ['전체', ...preferredOrder.where(present.contains)];
  }

  @override
  void initState() {
    super.initState();
    _period = widget.startDate == null && widget.endDateExclusive == null
        ? SavingsPeriod.currentMonth(DateTime.now())
        : SavingsPeriod.fromDates(widget.startDate, widget.endDateExclusive);
    _fetchSavingsHistory();
  }

  Future<void> _fetchSavingsHistory() async {
    if (_period == null) {
      _setLoadError('조회 기간이 올바르지 않아요. 리포트에서 기간을 다시 선택해 주세요.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.get(
        ApiClient.uri('/api/savings/history', {
          'startDate': _period.startDate,
          'endDateExclusive': _period.endDateExclusive,
        }),
        headers: ApiClient.jsonHeaders(auth: true),
      ).timeout(ApiClient.defaultTimeout);

      if (!mounted) return;
      if (response.statusCode == 200) {
        // 💡 실제 API는 List<SavingsHistoryResponse> 직렬 배열을 반환합니다.
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> historyData = decoded is List ? decoded : [];
        final storeSources = await _lookUpStoreSources(historyData);
        if (!mounted) return;

        final parsed = historyData.map((item) {
          final source =
              _recordedSource(item) ??
              storeSources[item['storeId']?.toString().trim()];
          final isGov = source == 'GOV';
          final String badgeText = isGov
              ? '정부 인증'
              : source == 'USER'
              ? '사용자 제보'
              : '출처 확인 필요';
          final Color badgeColor = isGov
              ? const Color(0xFF2563EB)
              : const Color(0xFFF97316);
          final Color badgeBg = isGov
              ? const Color(0xFFEFF4FF)
              : const Color(0xFFFFF3EA);

          final int priceVal = (item['price'] as num?)?.toInt() ?? 0;
          final bool isFree = item['isFree'] == true;
          final int savedVal = isFree
              ? 0
              : (item['savedAmount'] as num?)?.toInt() ?? 0;

          final String dateRaw = _visitDateText(item);
          final String category = normalizeSavingsCategory(
            item['category'] ?? item['industry'],
          );

          return SavingsDetailItem(
            category: category,
            badgeText: badgeText,
            badgeColor: badgeColor,
            badgeBg: badgeBg,
            date: _formatDate(dateRaw),
            dateValue: _parseDate(dateRaw),
            storeName: item['storeName']?.toString() ?? '미등록 매장',
            menuName: item['menu']?.toString() ?? '기타',
            price: isFree ? '무료' : '${_formatCurrency(priceVal)}원',
            savingAmount: isFree
                ? '무료 이용'
                : '공공 기준가 대비 ${_formatCurrency(savedVal)}원 절약',
            savedAmountValue: savedVal,
          );
        }).toList();

        final periodItems = parsed
            .where(
              (item) =>
                  item.dateValue != null && _period.contains(item.dateValue!),
            )
            .toList();

        final totalSaved = periodItems.fold<int>(
          0,
          (sum, it) => sum + it.savedAmountValue,
        );
        final visitCount = periodItems.length;
        final averageSaved = visitCount > 0 ? totalSaved ~/ visitCount : 0;

        setState(() {
          _allItems = periodItems;
          _totalSavedAmount = totalSaved;
          _visitCount = visitCount;
          _averageSaved = averageSaved;
          _isLoading = false;
        });
      } else {
        _setLoadError('절약 내역을 불러오지 못했어요.');
      }
    } catch (e) {
      debugPrint('절약 내역 조회 오류: $e');
      if (mounted) _setLoadError('네트워크 오류로 절약 내역을 불러오지 못했어요.');
    }
  }

  void _setLoadError(String message) {
    if (!mounted) return;
    setState(() {
      _allItems = [];
      _totalSavedAmount = 0;
      _visitCount = 0;
      _averageSaved = 0;
      _errorMessage = message;
      _isLoading = false;
    });
  }

  static String _visitDateText(dynamic item) =>
      item['date']?.toString() ?? item['visitedAt']?.toString() ?? '';

  /// 절약 내역에 담긴 매장 출처입니다. 서버는 지도·매장 상세와 같은 출처를
  /// storeSource로 보냅니다. 매장을 찾지 못했거나 이전 서버라 이 값이 없으면
  /// isGov로 정부 인증 여부만 알 수 있습니다.
  static String? _recordedSource(dynamic item) {
    final source = item['storeSource']?.toString().trim().toUpperCase();
    if (source == 'GOV' || source == 'USER') return source;
    if (source == null && item['isGov'] == true) return 'GOV';
    return null;
  }

  /// 출처를 받지 못한 기간 안의 방문 기록은 매장 정보로 실제 출처를 확인합니다.
  /// 지도와 매장 상세도 이 매장 정보의 출처를 쓰므로 같은 매장이 화면마다 다르게
  /// 보이지 않습니다. 조회하지 못한 매장은 출처를 추측하지 않습니다.
  Future<Map<String, String>> _lookUpStoreSources(List<dynamic> history) async {
    final period = _period;
    if (period == null) return const {};
    final storeIds = <String>{};
    for (final item in history) {
      if (item is! Map || _recordedSource(item) != null) continue;
      final date = _parseDate(_visitDateText(item));
      final storeId = item['storeId']?.toString().trim() ?? '';
      if (date != null && period.contains(date) && storeId.isNotEmpty) {
        storeIds.add(storeId);
      }
    }
    final results = await Future.wait(
      storeIds.map((storeId) async {
        try {
          final response = await ApiClient.get(
            ApiClient.uri('/api/stores/${Uri.encodeComponent(storeId)}'),
            headers: ApiClient.jsonHeaders(),
            timeout: const Duration(seconds: 5),
          );
          if (response.statusCode != 200) return null;
          final store = jsonDecode(utf8.decode(response.bodyBytes));
          if (store is! Map) return null;
          final id = (store['storeId'] ?? store['id'])?.toString();
          final source = store['source']?.toString().trim().toUpperCase();
          if (id != storeId || (source != 'GOV' && source != 'USER')) {
            return null;
          }
          return MapEntry(storeId, source!);
        } catch (error) {
          debugPrint('절약 내역 매장 출처 조회 실패: $error');
          return null;
        }
      }),
    );
    return Map.fromEntries(results.nonNulls);
  }

  /// ISO 8601/점 형식 날짜 문자열을 파싱 (실패 시 null)
  DateTime? _parseDate(String raw) {
    return SavingsPeriod.koreanDate(raw.trim());
  }

  /// "2026.08.03" 형태로 표시
  String _formatDate(String raw) {
    final d = _parseDate(raw);
    if (d == null) return raw;
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;

    final filteredItems = _allItems.where((item) {
      if (_selectedFilter == '전체') return true;
      return item.category == _selectedFilter;
    }).toList();

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: Stack(
        children: [
          Positioned.fill(child: const ColoredBox(color: Color(0xFFF4F6FA))),
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom AppBar
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.only(
                    top: topOffset + 11.98876953125,
                    bottom: 12,
                    left: 8,
                    right: AppSizes.horizontalPadding,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '리포트로 돌아가기',
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go(AppRoutes.savingsReportDashboard),
                      ),
                      const Expanded(
                        child: Text(
                          '절약 상세 내역',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Noto Sans KR',
                            fontFamilyFallback: ['Noto Sans KR'],
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance for back button
                    ],
                  ),
                ),
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.only(
                      top: 16,
                      bottom: safePadding.bottom + 20,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.horizontalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(
                              AppSizes.horizontalPadding,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEFF4FF), Color(0xFFFFF3EA)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_period?.title ?? '선택 기간'} 누적 절약',
                                  style: const TextStyle(
                                    fontFamily: 'Noto Sans KR',
                                    fontFamilyFallback: ['Noto Sans KR'],
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppSizes.smallSpacing),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _formatCurrency(_totalSavedAmount),
                                      style: const TextStyle(
                                        fontFamily: 'Noto Sans KR',
                                        fontFamilyFallback: ['Noto Sans KR'],
                                        color: Color(0xFF10B981),
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      '원',
                                      style: TextStyle(
                                        fontFamily: 'Noto Sans KR',
                                        fontFamilyFallback: ['Noto Sans KR'],
                                        color: Color(0xFF10B981),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Text(
                                      '📍 $_visitCount회 방문',
                                      style: const TextStyle(
                                        fontFamily: 'Noto Sans KR',
                                        fontFamilyFallback: ['Noto Sans KR'],
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '· 평균 ${_formatCurrency(_averageSaved)}원 절약',
                                      style: const TextStyle(
                                        fontFamily: 'Noto Sans KR',
                                        fontFamilyFallback: ['Noto Sans KR'],
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSizes.itemSpacing),
                          // Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children:
                                  _availableCategories
                                      .expand(
                                        (category) => [
                                          _buildChip(category),
                                          const SizedBox(
                                            width: AppSizes.smallSpacing,
                                          ),
                                        ],
                                      )
                                      .toList()
                                    ..removeLast(),
                            ),
                          ),
                          const SizedBox(height: AppSizes.itemSpacing),
                          // List of Savings
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: CircularProgressIndicator(
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            )
                          else if (_errorMessage != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'Noto Sans KR',
                                        fontFamilyFallback: ['Noto Sans KR'],
                                        color: Color(0xFF64748B),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: _fetchSavingsHistory,
                                      child: const Text('다시 시도'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (filteredItems.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Text(
                                  '절약 내역이 없습니다.',
                                  style: TextStyle(
                                    fontFamily: 'Noto Sans KR',
                                    fontFamilyFallback: ['Noto Sans KR'],
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...filteredItems.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildSavingItem(
                                  badgeText: item.badgeText,
                                  badgeColor: item.badgeColor,
                                  badgeBg: item.badgeBg,
                                  date: item.date,
                                  storeName: item.storeName,
                                  menuName: item.menuName,
                                  price: item.price,
                                  savingAmount: item.savingAmount,
                                ),
                              );
                            }),
                          const SizedBox(height: AppSizes.itemSpacing),
                          // Info Banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F6FA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF64748B),
                                  size: 14,
                                ),
                                SizedBox(width: AppSizes.smallSpacing),
                                Expanded(
                                  child: Text(
                                    '절약 금액은 참가격과 착한가격업소의 실제 등록 가격을 기준으로 계산돼요.',
                                    style: TextStyle(
                                      fontFamily: 'Noto Sans KR',
                                      fontFamilyFallback: ['Noto Sans KR'],
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text) {
    final isSelected = _selectedFilter == text;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.horizontalPadding,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: isSelected
              ? null
              : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Noto Sans KR',
            fontFamilyFallback: const ['Noto Sans KR'],
            color: isSelected ? Colors.white : const Color(0xFF374151),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSavingItem({
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required String date,
    required String storeName,
    required String menuName,
    required String price,
    required String savingAmount,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          badgeText,
                          style: TextStyle(
                            fontFamily: 'Noto Sans KR',
                            fontFamilyFallback: const ['Noto Sans KR'],
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.smallSpacing),
                  Text(
                    date,
                    style: const TextStyle(
                      fontFamily: 'Noto Sans KR',
                      fontFamilyFallback: ['Noto Sans KR'],
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.smallSpacing),
          Text(
            storeName,
            style: const TextStyle(
              fontFamily: 'Noto Sans KR',
              fontFamilyFallback: ['Noto Sans KR'],
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                menuName,
                style: const TextStyle(
                  fontFamily: 'Noto Sans KR',
                  fontFamilyFallback: ['Noto Sans KR'],
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  fontFamily: 'Noto Sans KR',
                  fontFamilyFallback: ['Noto Sans KR'],
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  savingAmount,
                  style: const TextStyle(
                    fontFamily: 'Noto Sans KR',
                    fontFamilyFallback: ['Noto Sans KR'],
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
