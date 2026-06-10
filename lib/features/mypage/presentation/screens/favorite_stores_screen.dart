import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class FavoriteStoreModel {
  final String id;
  final String category;
  final String iconEmoji;
  final Color iconBgColor;
  final String badgeText;
  final Color badgeColor;
  final Color badgeBgColor;
  final String distance;
  final String storeName;
  final String menu;
  final String price;
  final Color priceColor;
  final String? alertText;
  final Color? alertColor;
  final String buttonText;
  final Color buttonColor;
  final Color buttonTextColor;
  bool isFavorite;

  FavoriteStoreModel({
    required this.id,
    required this.category,
    required this.iconEmoji,
    required this.iconBgColor,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeBgColor,
    required this.distance,
    required this.storeName,
    required this.menu,
    required this.price,
    required this.priceColor,
    this.alertText,
    this.alertColor,
    required this.buttonText,
    required this.buttonColor,
    required this.buttonTextColor,
    this.isFavorite = true,
  });
}

class FavoriteStoresScreen extends StatefulWidget {
  const FavoriteStoresScreen({super.key});

  @override
  State<FavoriteStoresScreen> createState() => _FavoriteStoresScreenState();
}

class _FavoriteStoresScreenState extends State<FavoriteStoresScreen> {
  String _selectedFilter = '전체';

  final List<FavoriteStoreModel> _allStores = [
    FavoriteStoreModel(
      id: '1',
      category: '음식점',
      iconEmoji: '🍚',
      iconBgColor: const Color(0xFFEFF4FF),
      badgeText: '정부 인증',
      badgeColor: const Color(0xFF2563EB),
      badgeBgColor: const Color(0xFFEFF4FF),
      distance: '320m',
      storeName: '착한분식',
      menu: '김치찌개',
      price: '5,500원',
      priceColor: const Color(0xFF2563EB),
      alertText: '✓ 최근 가격 변동 없음',
      alertColor: const Color(0xFF64748B),
      buttonText: '길찾기',
      buttonColor: const Color(0xFF2563EB),
      buttonTextColor: Colors.white,
    ),
    FavoriteStoreModel(
      id: '2',
      category: '카페',
      iconEmoji: '☕',
      iconBgColor: const Color(0xFFFFF3EA),
      badgeText: '사용자 제보',
      badgeColor: const Color(0xFFF97316),
      badgeBgColor: const Color(0xFFFFF3EA),
      distance: '540m',
      storeName: '동네카페',
      menu: '아메리카노',
      price: '2,000원',
      priceColor: const Color(0xFFF97316),
      alertText: '⚠️ 가격 변동 제보 1건',
      alertColor: const Color(0xFFF97316),
      buttonText: '상세보기',
      buttonColor: const Color(0xFFF1F5F9),
      buttonTextColor: const Color(0xFF0F172A),
    ),
    FavoriteStoreModel(
      id: '3',
      category: '생활서비스',
      iconEmoji: '✂️',
      iconBgColor: const Color(0xFFEFF4FF),
      badgeText: '정부 인증',
      badgeColor: const Color(0xFF2563EB),
      badgeBgColor: const Color(0xFFEFF4FF),
      distance: '1.1km',
      storeName: '착한미용실',
      menu: '커트',
      price: '8,000원',
      priceColor: const Color(0xFF2563EB),
      buttonText: '길찾기',
      buttonColor: const Color(0xFF2563EB),
      buttonTextColor: Colors.white,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;

    final filteredStores = _allStores
        .where((store) => store.isFavorite && (_selectedFilter == '전체' || store.category == _selectedFilter))
        .toList();

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      child: Stack(
        children: [
          // Content Scroll
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: topOffset + 48.878, // Below header
                bottom: 40 + bottomOffset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Search Box
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.909),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 16),
                          SizedBox(width: 8),
                          Text(
                            '찜한 매장 검색',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              height: 19.5 / 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildFilterChip('전체'),
                        const SizedBox(width: 8),
                        _buildFilterChip('음식점'),
                        const SizedBox(width: 8),
                        _buildFilterChip('카페'),
                        const SizedBox(width: 8),
                        _buildFilterChip('생활서비스'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // List Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              fontSize: 12,
                              height: 18 / 12,
                            ),
                            children: [
                              const TextSpan(text: '총 ', style: TextStyle(color: Color(0xFF64748B))),
                              TextSpan(text: '${filteredStores.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const TextSpan(text: '개의 매장', style: TextStyle(color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        const Text(
                          '최근 추가순 ▾',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: ['Noto Sans KR'],
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                            fontSize: 11,
                            height: 16.5 / 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // List Items
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: filteredStores.map((store) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildFavoriteItem(store),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Bottom Suggestion Box
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(0xFFF4F6FA),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(Icons.add, color: Color(0xFF0F172A), size: 18),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '자주 가는 매장을 더 저장해보세요',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontFamilyFallback: ['Noto Sans KR'],
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    fontSize: 13,
                                    height: 19.5 / 13,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '가격 변동 알림을 받을 수 있어요',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontFamilyFallback: ['Noto Sans KR'],
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    height: 16.5 / 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Custom AppBar
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: topOffset + 48.878,
              padding: EdgeInsets.only(top: topOffset),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.909),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 13.98,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0A0A0A)),
                    ),
                  ),
                  const Positioned.fill(
                    child: Center(
                      child: Text(
                        '찜한 매장',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A0A0A),
                          fontSize: 16,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 20,
                    top: 13.98,
                    child: Icon(Icons.more_horiz_rounded, size: 24, color: Color(0xFF0A0A0A)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13.9, vertical: 7.9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? Colors.transparent : const Color(0xFFE5E7EB), width: 0.909),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: const ['Noto Sans KR'],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontSize: 12,
            height: 18 / 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteItem(FavoriteStoreModel store) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.909),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: store.iconBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                store.iconEmoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: store.badgeBgColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: store.badgeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            store.badgeText,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: const ['Noto Sans KR'],
                              fontWeight: FontWeight.w600,
                              color: store.badgeColor,
                              fontSize: 10,
                              height: 15 / 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      store.distance,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontFamilyFallback: ['Noto Sans KR'],
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        height: 16.5 / 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  store.storeName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontFamilyFallback: ['Noto Sans KR'],
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A0A0A),
                    fontSize: 14,
                    height: 21 / 14,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      store.menu,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontFamilyFallback: ['Noto Sans KR'],
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        height: 18 / 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      store.price,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontFamilyFallback: const ['Noto Sans KR'],
                        fontWeight: FontWeight.bold,
                        color: store.priceColor,
                        fontSize: 13,
                        height: 19.5 / 13,
                      ),
                    ),
                  ],
                ),
                if (store.alertText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    store.alertText!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontFamilyFallback: const ['Noto Sans KR'],
                      fontWeight: FontWeight.w600,
                      color: store.alertColor,
                      fontSize: 10,
                      height: 15 / 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    store.isFavorite = !store.isFavorite;
                  });
                },
                child: Icon(
                  store.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: store.isFavorite ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: store.buttonColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      store.buttonText,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontFamilyFallback: const ['Noto Sans KR'],
                        fontWeight: FontWeight.bold,
                        color: store.buttonTextColor,
                        fontSize: 11,
                        height: 16.5 / 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
