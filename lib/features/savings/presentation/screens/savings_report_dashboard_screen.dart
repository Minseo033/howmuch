import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_bottom_nav.dart';
import 'dart:convert';
import 'package:howmuch/core/network/api_client.dart';

@visibleForTesting
List<Map<String, dynamic>> parseSavingsChartItems(List<dynamic> chartItems) {
  return chartItems.map<Map<String, dynamic>>((item) {
    final map = item as Map<String, dynamic>;
    return <String, dynamic>{
      'label': map['label']?.toString() ?? '',
      'amount': (map['amount'] as num?)?.toInt() ?? 0,
      'isMax': map['isMax'] == true,
    };
  }).toList();
}

class SavingsReportDashboardScreen extends StatefulWidget {
  const SavingsReportDashboardScreen({super.key});

  @override
  State<SavingsReportDashboardScreen> createState() =>
      _SavingsReportDashboardScreenState();
}

class _SavingsReportDashboardScreenState
    extends State<SavingsReportDashboardScreen> {
  String _selectedTab = '이번 달';
  bool _isLoading = false;
  bool _loadFailed = false;
  Map<String, dynamic>? _statsData;

  /// 탭 라벨 → 백엔드 period 파라미터 매핑
  static const Map<String, String> _tabToPeriod = {
    '이번 달': 'this_month',
    '지난 달': 'last_month',
    '올해': 'this_year',
  };

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  /// 모든 탭 + 목표 + 찜/제보 개수를 병렬로 조회해 캐시에 담습니다.
  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final goal = await _fetchGoal();
      final favoritesCount = await _fetchFavoritesCount();
      final reportsCount = await _fetchReportsCount();
      final now = DateTime.now();

      final results = <String, dynamic>{};
      bool anyStatsLoaded = false;
      for (final entry in _tabToPeriod.entries) {
        final stats = await _fetchStats(entry.value);
        if (stats != null) anyStatsLoaded = true;
        results[entry.key] = _buildTabData(
          entry.key,
          stats,
          goal,
          favoritesCount,
          reportsCount,
          now,
        );
      }

      if (!mounted) return;
      setState(() {
        // 💡 감사 이슈: 통계 API가 전부 실패했는데 가짜 숫자를 실데이터처럼
        //    보여주던 폼백 제거 — 실패 시 에러 안내 UI로 전환합니다.
        if (anyStatsLoaded) {
          _statsData = results;
          _loadFailed = false;
        } else {
          _statsData = null;
          _loadFailed = true;
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('절약 대시보드 통계 조회 오류: $e');
      if (!mounted) return;
      setState(() {
        _statsData = null;
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  /// GET /api/savings/stats?period=... → SavingsStatsResponse
  Future<Map<String, dynamic>?> _fetchStats(String period) async {
    try {
      final response = await ApiClient.get(
        ApiClient.uri('/api/savings/stats', {'period': period}),
        headers: ApiClient.jsonHeaders(auth: true),
      ).timeout(ApiClient.defaultTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('절약 통계 조회 오류($period): $e');
    }
    return null;
  }

  /// GET /api/savings/goal → goalAmount (미설정 시 0)
  Future<int> _fetchGoal() async {
    try {
      final response = await ApiClient.get(
        ApiClient.uri('/api/savings/goal'),
        headers: ApiClient.jsonHeaders(auth: true),
      ).timeout(ApiClient.defaultTimeout);
      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return (data['goalAmount'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('절약 목표 조회 오류: $e');
    }
    return 0;
  }

  /// GET /api/favorites → 찜한 매장 개수
  Future<int> _fetchFavoritesCount() async {
    try {
      final response = await ApiClient.get(
        ApiClient.uri('/api/favorites'),
        headers: ApiClient.jsonHeaders(auth: true),
      ).timeout(ApiClient.defaultTimeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded is List ? decoded.length : 0;
      }
    } catch (e) {
      debugPrint('찜 목록 조회 오류: $e');
    }
    return 0;
  }

  /// GET /api/report/my → 내 제보 개수
  Future<int> _fetchReportsCount() async {
    try {
      final response = await ApiClient.get(
        ApiClient.uri('/api/report/my'),
        headers: ApiClient.jsonHeaders(auth: true),
      ).timeout(ApiClient.defaultTimeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded is List ? decoded.length : 0;
      }
    } catch (e) {
      debugPrint('내 제보 조회 오류: $e');
    }
    return 0;
  }

  /// SavingsStatsResponse → 화면용 탭 데이터 구조로 변환
  Map<String, dynamic> _buildTabData(
    String tab,
    Map<String, dynamic>? stats,
    int goal,
    int favoritesCount,
    int reportsCount,
    DateTime now,
  ) {
    final chartItems = (stats?['chartItems'] as List?) ?? const [];
    final savings = parseSavingsChartItems(chartItems);

    String chartDate;
    if (tab == '이번 달') {
      chartDate = '${now.year}.${now.month.toString().padLeft(2, '0')}';
    } else if (tab == '지난 달') {
      final last = DateTime(now.year, now.month - 1, 1);
      chartDate = '${last.year}.${last.month.toString().padLeft(2, '0')}';
    } else {
      chartDate = '${now.year}';
    }

    return {
      'savedAmount': (stats?['totalSavedAmount'] as num?)?.toInt() ?? 0,
      'goalAmount': goal,
      'visits': (stats?['totalVisits'] as num?)?.toInt() ?? 0,
      'favorites': favoritesCount,
      'reports': reportsCount,
      'recommendation': _summaryFor(savings),
      'chartTitle': stats?['chartTitle'] ?? '절약 금액',
      'chartDate': chartDate,
      'savings': savings,
    };
  }

  String _summaryFor(List<Map<String, dynamic>> savings) {
    if (savings.isEmpty) return '아직 이 기간의 절약 기록이 없어요';
    final maxItem = savings.reduce((a, b) {
      final aAmount = (a['amount'] as num?)?.toInt() ?? 0;
      final bAmount = (b['amount'] as num?)?.toInt() ?? 0;
      return aAmount >= bAmount ? a : b;
    });
    final amount = (maxItem['amount'] as num?)?.toInt() ?? 0;
    if (amount <= 0) return '아직 이 기간의 절약 기록이 없어요';
    return '${maxItem['label']}에 ${_formatCurrency(amount)}원을 가장 많이 절약했어요';
  }

  /// 로드 실패 시 표시할 에러/재시도 UI
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFF64748B),
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              '절약 데이터를 불러오지 못했어요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: ['Noto Sans KR'],
                color: Color(0xFF0F172A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '네트워크 상태를 확인하고 다시 시도해주세요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: ['Noto Sans KR'],
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _fetchAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  '다시 시도',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontFamilyFallback: ['Noto Sans KR'],
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;
    final bottomNavHeight = HowmuchBottomNav.heightFor(bottomOffset);

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: Stack(
        children: [
          Positioned.fill(child: const ColoredBox(color: Color(0xFFF4F6FA))),

          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom AppBar (Pinned)
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.only(
                    top: topOffset + 11.98876953125,
                    bottom: 12,
                    left: AppSizes.horizontalPadding,
                    right: AppSizes.horizontalPadding,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '절약 리포트',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          color: Color(0xFF0A0A0A),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                context.push(AppRoutes.savingsGoalSetting),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F8F1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.flag,
                                    color: Color(0xFF10B981),
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '목표 설정',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontFamilyFallback: ['Noto Sans KR'],
                                      color: Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.itemSpacing),
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.notifications),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: Color(0xFF0F172A),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tabs (Pinned)
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppSizes.horizontalPadding,
                          right: AppSizes.horizontalPadding,
                          bottom: 12,
                        ),
                        child: Row(
                          children: [
                            _buildTab('이번 달'),
                            const SizedBox(width: AppSizes.smallSpacing),
                            _buildTab('지난 달'),
                            const SizedBox(width: AppSizes.smallSpacing),
                            _buildTab('올해'),
                          ],
                        ),
                      ),
                      const Divider(
                        height: 1,
                        thickness: 0.909,
                        color: Color(0xFFE5E7EB),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2563EB),
                          ),
                        )
                      : _loadFailed
                      ? SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom: bottomNavHeight + 20,
                          ),
                          child: _buildErrorState(),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom: bottomNavHeight + 20,
                          ),
                          child: _buildDynamicContent(),
                        ),
                ),
              ],
            ),
          ),

          // Bottom Nav
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomNavHeight,
            child: HowmuchBottomNav(
              activeTab: HowmuchBottomTab.savings,
              safeBottom: bottomOffset,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicContent() {
    String titlePrefix = '';
    int displayedSaved = 0;
    int goalAmount = 0;
    String chartTitle = '';
    String chartDate = '';
    List<Widget> chartBars = [];
    int visits = 0, favorites = 0, reports = 0;
    String recommendationSub = '';

    final tabData = _statsData?[_selectedTab];

    if (tabData != null) {
      titlePrefix = _selectedTab;
      displayedSaved = (tabData['savedAmount'] as num?)?.toInt() ?? 0;
      goalAmount = (tabData['goalAmount'] as num?)?.toInt() ?? 0;
      chartTitle = tabData['chartTitle'] ?? '절약 금액';
      chartDate = tabData['chartDate'] ?? '';
      visits = (tabData['visits'] as num?)?.toInt() ?? 0;
      favorites = (tabData['favorites'] as num?)?.toInt() ?? 0;
      reports = (tabData['reports'] as num?)?.toInt() ?? 0;
      recommendationSub = tabData['recommendation'] ?? '';

      final List<dynamic> savings = tabData['savings'] ?? [];
      chartBars = savings.map((s) {
        final label = s['label']?.toString() ?? '';
        final amountVal = s['amount'];
        final String amountStr = amountVal is num && amountVal >= 10000
            ? '${(amountVal / 10000).toStringAsFixed(1).replaceAll('.0', '')}만'
            : amountVal is num
            ? '${_formatCurrency(amountVal.toInt())}원'
            : s['amount']?.toString() ?? '';
        final isMax = s['isMax'] == true;

        final double rawAmt = amountVal is num ? amountVal.toDouble() : 0.0;
        double height = 40.0;
        if (savings.isNotEmpty) {
          final maxAmt = savings
              .map((item) => (item['amount'] as num?)?.toDouble() ?? 0.0)
              .reduce((a, b) => a > b ? a : b);
          if (maxAmt > 0) {
            height = (rawAmt / maxAmt) * 100.0;
            if (height < 20) height = 20; // 최소 높이 보장
          }
        }
        return _buildBar(
          label: label,
          amount: amountStr,
          height: height,
          isMax: isMax,
        );
      }).toList();
    } else {
      titlePrefix = _selectedTab;
      displayedSaved = 0;
      chartTitle = '절약 금액';
      chartDate = '';
      chartBars = [];
      visits = 0;
      favorites = 0;
      reports = 0;
      recommendationSub = '데이터를 불러올 수 없습니다';
    }

    // Format the number
    final formattedSaved = displayedSaved.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    // 목표 달성률은 목표가 적용되는 이번 달에만 표시합니다.
    int percentage = 0;
    if (_selectedTab == '이번 달' && goalAmount > 0) {
      percentage = ((displayedSaved / goalAmount) * 100).toInt();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSizes.horizontalPadding),
          child: Column(
            children: [
              // Savings Card
              GestureDetector(
                onTap: () => context.push(AppRoutes.savingsDetail),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.horizontalPadding),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF34D399), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.savings_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$titlePrefix 절약 금액',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formattedSaved,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '원',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.largeSpacing),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _selectedTab == '이번 달'
                              ? goalAmount > 0
                                    ? '목표 대비 $percentage% 달성'
                                    : '이번 달 목표가 아직 없어요'
                              : '$visits회 방문 기록 기준',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: ['Noto Sans KR'],
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.itemSpacing),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.horizontalPadding,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              color: Color(0xFF059669),
                              size: 18,
                            ),
                            const SizedBox(width: AppSizes.smallSpacing),
                            Text(
                              visits > 0
                                  ? '$visits번의 방문 인증으로 계산했어요'
                                  : '방문 인증을 완료하면 절약액이 기록돼요',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontFamilyFallback: ['Noto Sans KR'],
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.itemSpacing),

              // Chart Card
              GestureDetector(
                onTap: () => context.push(AppRoutes.savingsDetail),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.horizontalPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            chartTitle,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF0A0A0A),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            chartDate,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: chartBars,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.itemSpacing),

              // Stats Row
              Row(
                children: [
                  _buildStatCard('$visits', '방문 매장', const Color(0xFF2563EB)),
                  _buildStatCard(
                    '$favorites',
                    '찜한 매장',
                    const Color(0xFFF97316),
                  ),
                  _buildStatCard('$reports', '제보 매장', const Color(0xFF10B981)),
                ],
              ),
              const SizedBox(height: AppSizes.itemSpacing),

              // 실제 절약 기록 요약
              Container(
                padding: const EdgeInsets.all(AppSizes.horizontalPadding),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.restaurant,
                        color: Color(0xFFF97316),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '기록 요약',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF92400E),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            recommendationSub,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String text) {
    final isSelected = _selectedTab == text;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.horizontalPadding,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: const ['Noto Sans KR'],
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBar({
    required String label,
    required String amount,
    required double height,
    required bool isMax,
  }) {
    return Column(
      children: [
        if (isMax)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '최대',
              style: TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: ['Noto Sans KR'],
                color: Color(0xFF2563EB),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (isMax) const SizedBox(height: 4),
        Container(
          width: 32,
          height: height,
          decoration: BoxDecoration(
            color: isMax ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: AppSizes.smallSpacing),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['Noto Sans KR'],
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: const ['Noto Sans KR'],
            color: isMax ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
            fontSize: 11,
            fontWeight: isMax ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: const ['Noto Sans KR'],
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: ['Noto Sans KR'],
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
