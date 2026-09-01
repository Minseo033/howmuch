import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/core/theme/app_colors.dart';

import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/app/app_routes.dart';

class FavoriteStoresScreen extends ConsumerStatefulWidget {
  const FavoriteStoresScreen({super.key});

  @override
  ConsumerState<FavoriteStoresScreen> createState() =>
      _FavoriteStoresScreenState();
}

class _FavoriteStoresScreenState extends ConsumerState<FavoriteStoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  FavoriteStoreSort _sort = FavoriteStoreSort.recent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoriteStoresProvider.notifier).loadFavorites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final topOffset = safePadding.top;
    final bottomOffset = safePadding.bottom;

    final favoritesState = ref.watch(favoriteStoresProvider);
    final allStores =
        favoritesState.valueOrNull ?? const <FavoriteStoreModel>[];
    final query = _searchQuery.trim().toLowerCase();
    final filteredStores = allStores
        .where(
          (store) =>
              query.isEmpty || store.storeName.toLowerCase().contains(query),
        )
        .toList();
    sortFavoriteStores(filteredStores, _sort);

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
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: '찜한 매장 검색',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textLight,
                            size: 19,
                          ),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '검색어 지우기',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                ),
                          filled: true,
                          fillColor: AppColors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                              width: 0.909,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.2,
                            ),
                          ),
                        ),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['Noto Sans KR'],
                          color: AppColors.ink,
                          fontSize: 13,
                          height: 19.5 / 13,
                        ),
                      ),
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
                        PopupMenuButton<FavoriteStoreSort>(
                          tooltip: '정렬 방식 선택',
                          initialValue: _sort,
                          onSelected: (value) => setState(() => _sort = value),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: FavoriteStoreSort.recent,
                              child: Text('최근 추가순'),
                            ),
                            PopupMenuItem(
                              value: FavoriteStoreSort.name,
                              child: Text('매장 이름순'),
                            ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _sort.label,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontFamilyFallback: ['Noto Sans KR'],
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    height: 16.5 / 11,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // List Items
                  favoritesState.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildMessageBox(
                        icon: Icons.wifi_off_rounded,
                        title: '찜한 매장을 불러오지 못했어요',
                        message: '잠시 후 다시 시도해 주세요.',
                        actionText: '다시 불러오기',
                        onAction: () {
                          ref
                              .read(favoriteStoresProvider.notifier)
                              .loadFavorites(force: true);
                        },
                      ),
                    ),
                    data: (_) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: filteredStores.isEmpty
                          ? _buildMessageBox(
                              icon: Icons.favorite_border_rounded,
                              title: query.isEmpty
                                  ? '아직 찜한 매장이 없어요'
                                  : '검색 결과가 없어요',
                              message: query.isEmpty
                                  ? '매장 상세 화면에서 하트를 누르면 여기에 모아볼 수 있어요.'
                                  : '다른 매장명으로 검색해 보세요.',
                            )
                          : Column(
                              children: filteredStores.map((store) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildFavoriteItem(store),
                                );
                              }).toList(),
                            ),
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

  Widget _buildMessageBox({
    required IconData icon,
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.909),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontFamilyFallback: ['Noto Sans KR'],
              fontWeight: FontWeight.bold,
              color: AppColors.black,
              fontSize: 14,
              height: 21 / 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontFamilyFallback: ['Noto Sans KR'],
              color: AppColors.muted,
              fontSize: 12,
              height: 18 / 12,
            ),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onAction, child: Text(actionText)),
          ],
        ],
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
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
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
                    if (store.price.isNotEmpty)
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
                      color: store.alertColor != null
                          ? Color(store.alertColor!)
                          : null,
                      fontSize: 10,
                      height: 15 / 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _confirmFavoriteRemoval(store),
            style: TextButton.styleFrom(
              foregroundColor: Color(store.buttonTextColor),
              backgroundColor: Color(store.buttonColor),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.favorite_rounded, size: 15),
            label: Text(
              store.buttonText,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: ['Noto Sans KR'],
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmFavoriteRemoval(FavoriteStoreModel store) async {
    final removed = await context.push<bool>(
      AppRoutes.favoriteCancelConfirm,
      extra: {'storeId': store.id, 'storeName': store.storeName},
    );
    if (removed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${store.storeName} 찜을 해제했어요.')));
    }
  }
}

enum FavoriteStoreSort { recent, name }

extension on FavoriteStoreSort {
  String get label => switch (this) {
    FavoriteStoreSort.recent => '최근 추가순',
    FavoriteStoreSort.name => '매장 이름순',
  };
}

@visibleForTesting
void sortFavoriteStores(
  List<FavoriteStoreModel> stores,
  FavoriteStoreSort sort,
) {
  switch (sort) {
    case FavoriteStoreSort.recent:
      stores.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    case FavoriteStoreSort.name:
      stores.sort((a, b) => a.storeName.compareTo(b.storeName));
  }
}
