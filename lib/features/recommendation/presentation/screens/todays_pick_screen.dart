import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class TodaysPickItem {
  final String id;
  final String storeName;
  final String menuName;
  final String price;
  final String tipText;
  final String distance;
  final String badgeText;
  final Color badgeColor;
  final Color badgeBg;
  final List<String> tags; // '날씨 기반', '가까운 거리', '저렴한 가격'

  TodaysPickItem({
    required this.id,
    required this.storeName,
    required this.menuName,
    required this.price,
    required this.tipText,
    required this.distance,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeBg,
    required this.tags,
  });
}

class TodaysPickScreen extends StatefulWidget {
  const TodaysPickScreen({super.key});

  @override
  State<TodaysPickScreen> createState() => _TodaysPickScreenState();
}

class _TodaysPickScreenState extends State<TodaysPickScreen> {
  String _selectedFilter = '날씨 기반';

  final List<TodaysPickItem> _allItems = [
    TodaysPickItem(
      id: '1',
      storeName: '착한칼국수',
      menuName: '칼국수',
      price: '5,000원',
      tipText: '💡 비 오는 날 인기 메뉴',
      distance: '450m',
      badgeText: '정부 인증',
      badgeColor: const Color(0xFF2563EB),
      badgeBg: const Color(0xFFEFF4FF),
      tags: ['날씨 기반', '가까운 거리'],
    ),
    TodaysPickItem(
      id: '2',
      storeName: '골목국밥',
      menuName: '돼지국밥',
      price: '6,500원',
      tipText: '💡 든든한 점심 추천',
      distance: '620m',
      badgeText: '사용자 제보',
      badgeColor: const Color(0xFFF97316),
      badgeBg: const Color(0xFFFFF3EA),
      tags: ['날씨 기반', '저렴한 가격'],
    ),
    TodaysPickItem(
      id: '3',
      storeName: '정다운분식',
      menuName: '우동',
      price: '4,500원',
      tipText: '💡 가까운 저가 메뉴',
      distance: '780m',
      badgeText: '정부 인증',
      badgeColor: const Color(0xFF2563EB),
      badgeBg: const Color(0xFFEFF4FF),
      tags: ['저렴한 가격'],
    ),
    TodaysPickItem(
      id: '4',
      storeName: '초가집삼계탕',
      menuName: '삼계탕',
      price: '11,000원',
      tipText: '💡 몸보신 특가',
      distance: '200m',
      badgeText: '정부 인증',
      badgeColor: const Color(0xFF2563EB),
      badgeBg: const Color(0xFFEFF4FF),
      tags: ['가까운 거리'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;

    final filteredItems = _allItems.where((item) => item.tags.contains(_selectedFilter)).toList();

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
                    right: 16,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.black,
                          size: 20,
                        ),
                        onPressed: () => context.pop(),
                      ),
                      const Expanded(
                        child: Text(
                          '오늘의 픽',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: ['Noto Sans KR'],
                            color: Color(0xFF0A0A0A),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Weather Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '2026.05.16 (토)',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontFamilyFallback: const ['Noto Sans KR'],
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          '비가 오는 날이네요 ☔️',
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
                                    const Text(
                                      '18°',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w300,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '🍜 따뜻한 국물 메뉴를 추천해요',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontFamilyFallback: ['Noto Sans KR'],
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Filter Chips
                          Row(
                            children: [
                              _buildFilterChip('날씨 기반', const Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              _buildFilterChip('가까운 거리', const Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              _buildFilterChip('저렴한 가격', const Color(0xFFF97316)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Pick Cards
                          ...filteredItems.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var item = entry.value;

                            Color indexBg;
                            Color indexText;
                            if (idx == 0) {
                              indexBg = const Color(0xFFEFF4FF);
                              indexText = const Color(0xFF2563EB);
                            } else if (idx == 1) {
                              indexBg = const Color(0xFFFFF3EA);
                              indexText = const Color(0xFFF97316);
                            } else {
                              indexBg = const Color(0xFFE8F8F1);
                              indexText = const Color(0xFF10B981);
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildPickCard(
                                index: (idx + 1).toString(),
                                indexBgColor: indexBg,
                                indexTextColor: indexText,
                                badgeText: item.badgeText,
                                badgeColor: item.badgeColor,
                                badgeBg: item.badgeBg,
                                distance: item.distance,
                                storeName: item.storeName,
                                menuName: item.menuName,
                                price: item.price,
                                tipText: item.tipText,
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          // Bottom Actions
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.map_outlined,
                                        color: Color(0xFF0F172A),
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '지도에서 보기',
                                        style: TextStyle(
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
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      context.push(AppRoutes.optimalRoute),
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF2563EB,
                                          ).withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.route,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '이 루트로 보기',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontFamilyFallback: [
                                              'Noto Sans KR',
                                            ],
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildFilterChip(String text, Color baseColor) {
    bool isSelected = _selectedFilter == text;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? baseColor.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: isSelected ? Border.all(color: baseColor) : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, color: isSelected ? baseColor : const Color(0xFF94A3B8), size: 6),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: const ['Noto Sans KR'],
                color: isSelected ? baseColor : const Color(0xFF475569),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickCard({
    required String index,
    required Color indexBgColor,
    required Color indexTextColor,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required String distance,
    required String storeName,
    required String menuName,
    required String price,
    required String tipText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Index Box
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: indexBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'PICK',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontFamilyFallback: ['Noto Sans KR'],
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      index,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontFamilyFallback: const ['Noto Sans KR'],
                        color: indexTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                fontFamily: 'Inter',
                                fontFamilyFallback: const ['Noto Sans KR'],
                                color: badgeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        distance,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    storeName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
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
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        price,
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
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tipText,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF475569),
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
          ],
        ),
      ),
    );
  }
}
