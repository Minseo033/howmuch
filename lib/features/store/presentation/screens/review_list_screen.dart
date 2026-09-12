import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';

class ReviewListScreen extends ConsumerStatefulWidget {
  final Store? store;
  const ReviewListScreen({super.key, this.store});

  @override
  ConsumerState<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends ConsumerState<ReviewListScreen> {
  int _selectedFilter = 0;

  final List<String> _filters = ['최신순', '별점 높은순', '별점 낮은순'];

  /// 공공데이터 매장은 별도 id가 없으므로 매장명을 storeId로 사용합니다.
  String get _storeId => widget.store?.storeName ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(storeReviewProvider.notifier).loadReviews(_storeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(storeReviewProvider)[_storeId];
    final reviews =
        List<Review>.from(reviewState?.valueOrNull ?? const <Review>[])
          ..sort((a, b) {
            if (_selectedFilter != 0 && a.stars != b.stars) {
              return _selectedFilter == 1
                  ? b.stars.compareTo(a.stars)
                  : a.stars.compareTo(b.stars);
            }
            return (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
              a.createdAt?.millisecondsSinceEpoch ?? 0,
            );
          });
    final reviewCount = reviews.length;
    final averageRating = reviewCount > 0
        ? reviews.map((r) => r.stars).reduce((a, b) => a + b) / reviewCount
        : 0.0;

    return FigmaMobileCanvas(
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: const CustomAppBar(title: '매장 리뷰'),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStoreHeader(averageRating, reviewCount),
              _buildFilterChips(),
              Expanded(
                child: _storeId.isEmpty
                    ? const Center(child: Text('매장을 선택한 뒤 리뷰를 확인해주세요.'))
                    : reviewState == null || reviewState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : reviewState.hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('리뷰를 불러오지 못했어요'),
                            TextButton(
                              onPressed: () => ref
                                  .read(storeReviewProvider.notifier)
                                  .loadReviews(_storeId, force: true),
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      )
                    : reviews.isEmpty
                    ? const Center(child: Text('아직 리뷰가 없어요. 첫 리뷰를 남겨보세요!'))
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(storeReviewProvider.notifier)
                            .loadReviews(_storeId, force: true),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: reviews.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _buildReviewCard(reviews[index]),
                        ),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: CustomBottomButton(
          text: '리뷰 작성하기',
          backgroundColor: AppColors.orangeTheme,
          onPressed: () {
            context.push(AppRoutes.reviewWrite, extra: widget.store);
          },
        ),
      ),
    );
  }

  Widget _buildStoreHeader(double averageRating, int reviewCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.store?.storeName ?? '매장 정보 없음',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successSubtle,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      widget.store?.isUserReported == true ? '사용자 제보' : '정부 인증',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ...List.generate(5, (i) {
                IconData icon;
                if (averageRating >= i + 1) {
                  icon = Icons.star_rounded; // 꽉 찬 별
                } else if (averageRating > i && averageRating < i + 1) {
                  icon = Icons.star_half_rounded; // 반 개 별
                } else {
                  icon = Icons.star_border_rounded; // 빈 별
                }
                return Icon(icon, color: AppColors.star, size: 20);
              }),
              const SizedBox(width: 6),
              Text(
                averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                ' · 리뷰 $reviewCount',
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = _selectedFilter == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.grey.shade300,
                ),
              ),
              child: Text(
                _filters[index],
                style: TextStyle(
                  color: selected ? AppColors.white : Colors.black87,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 정보
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                child: Text(
                  review.initial,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: i < review.stars
                                  ? AppColors.star
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          review.timeAgo,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 방문 메뉴 태그
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '방문: ${review.menu}',
              style: const TextStyle(
                color: AppColors.orangeTheme,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 리뷰 내용
          Text(
            review.content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
          // 사장님 답글
          if (review.ownerReply != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.subdirectory_arrow_right,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: '사장님: ',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: review.ownerReply,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
