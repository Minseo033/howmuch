import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/core/theme/app_colors.dart';

import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoriteStoresScreen extends ConsumerStatefulWidget {
  const FavoriteStoresScreen({super.key});

  @override
  ConsumerState<FavoriteStoresScreen> createState() => _FavoriteStoresScreenState();
}

class _FavoriteStoresScreenState extends ConsumerState<FavoriteStoresScreen> {
  String _selectedFilter = '전체';

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;

    final allStores = ref.watch(favoriteStoresProvider);

    final filteredStores = allStores
        .where(
          (store) =>
              store.isFavorite &&
              (_selectedFilter == '전체' || store.category == _selectedFilter),
        )
        .toList();

    return FigmaMobileCanvas(
      backgroundColor: AppColors.surface,
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
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.border,
                          width: 0.909,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: AppColors.textLight,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '찜한 매장 검색',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontFamilyFallback: ['Noto Sans KR'],
                              color: AppColors.textLight,
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
                              const TextSpan(
                                text: '총 ',
                                style: TextStyle(color: AppColors.muted),
                              ),
                              TextSpan(
                                text: '${filteredStores.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                              const TextSpan(
                                text: '개의 매장',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          '최근 추가순 ▾',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: ['Noto Sans KR'],
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.add,
                                color: AppColors.ink,
                                size: 18,
                              ),
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
                                    color: AppColors.ink,
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
                                    color: AppColors.muted,
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
                color: AppColors.white,
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 0.909),
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
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: AppColors.black,
                      ),
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
                          color: AppColors.black,
                          fontSize: 16,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 20,
                    top: 13.98,
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 24,
                      color: AppColors.black,
                    ),
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
          color: isSelected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? AppColors.transparent : AppColors.border,
            width: 0.909,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: const ['Noto Sans KR'],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.white : AppColors.textBody,
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.909),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Color(store.iconBgColor),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Color(store.badgeBgColor),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Color(store.badgeColor),
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
                              color: Color(store.badgeColor),
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
                        color: AppColors.muted,
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
                    color: AppColors.black,
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
                        color: AppColors.muted,
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
                        color: Color(store.priceColor),
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
                      color: store.alertColor != null ? Color(store.alertColor!) : null,
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
                  final stores = ref.read(favoriteStoresProvider);
                  final nextIsFavorite = !store.isFavorite;
                  
                  ref.read(favoriteStoresProvider.notifier).state = stores.map((s) {
                    if (s.id == store.id) {
                      return s.copyWith(isFavorite: nextIsFavorite);
                    }
                    return s;
                  }).toList();

                  final profile = ref.read(userProfileProvider);
                  ref.read(userProfileProvider.notifier).state = profile.copyWith(
                    favoriteStoreCount: profile.favoriteStoreCount + (nextIsFavorite ? 1 : -1),
                  );
                },
                child: Icon(
                  store.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: store.isFavorite
                      ? AppColors.error
                      : AppColors.textLight,
                  size: 20,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Color(store.buttonColor),
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
                        color: Color(store.buttonTextColor),
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
