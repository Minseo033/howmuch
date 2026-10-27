import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_button.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';
import 'package:howmuch/shared/widgets/keep_all_text.dart';

import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';

class ReviewListScreen extends ConsumerStatefulWidget {
  final Store? store;
  const ReviewListScreen({super.key, this.store});

  @override
  ConsumerState<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends ConsumerState<ReviewListScreen> {
  int _selectedFilter = 0;

  final List<String> _filters = ['최신순', '별점 높은순', '별점 낮은순'];

  String get _storeId => widget.store?.id.trim() ?? '';

  @override
  void initState() {
    super.initState();
    // Reviews loaded earlier in this session stay on screen while the list
    // reloads, so reviews written elsewhere since then appear (QA #11).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(storeReviewProvider.notifier).loadReviews(_storeId, force: true);
    });
  }

  Future<void> _refresh() async {
    await ref
        .read(storeReviewProvider.notifier)
        .loadReviews(_storeId, force: true);
    if (!mounted) return;
    final reviewState = ref.read(storeReviewProvider)[_storeId];
    // A failed refresh keeps the list, so say that it is not up to date.
    if (reviewState != null && reviewState.hasError && reviewState.hasValue) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          HowmuchSnackBar(
            content: const Text('리뷰를 새로고침하지 못했어요. 잠시 후 다시 시도해주세요.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(storeReviewProvider)[_storeId];
    final hasReviews = reviewState?.hasValue == true;
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
                    ? const _ReviewStatePanel(
                        icon: Icons.storefront_outlined,
                        title: '매장을 선택한 뒤 리뷰를 확인해주세요.',
                      )
                    : reviewState == null ||
                          (reviewState.isLoading && !hasReviews)
                    ? const _ReviewListSkeleton()
                    : reviewState.hasError && !hasReviews
                    ? _ReviewStatePanel(
                        icon: Icons.info_outline_rounded,
                        title: '리뷰를 불러오지 못했어요',
                        action: OutlinedButton.icon(
                          onPressed: () => ref
                              .read(storeReviewProvider.notifier)
                              .loadReviews(_storeId, force: true),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('다시 시도'),
                        ),
                      )
                    : reviews.isEmpty
                    ? const _ReviewStatePanel(
                        icon: Icons.rate_review_outlined,
                        title: '아직 리뷰가 없어요.',
                        message: '첫 리뷰를 남겨보세요!',
                        accent: true,
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
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
                      widget.store?.isUserReported == true
                          ? '사용자 제보'
                          : widget.store?.isGovernmentCertified == true
                          ? '정부 인증'
                          : '출처 확인 필요',
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
                  color: selected ? AppColors.primary : AppColors.borderMedium,
                ),
              ),
              child: Text(
                _filters[index],
                style: TextStyle(
                  color: selected ? AppColors.white : AppColors.textBody,
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
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
                                  : AppColors.disabled,
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
              color: AppColors.textBody,
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
                    // Text.rich, unlike RichText, takes the app font.
                    child: Text.rich(
                      TextSpan(
                        text: '사장님: ',
                        style: const TextStyle(
                          color: AppColors.textBody,
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

/// The empty, error and no-store states: one quiet card where the reviews
/// would start, scrollable so large text never overflows.
class _ReviewStatePanel extends StatelessWidget {
  const _ReviewStatePanel({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  /// Tints the icon with the brand color for an inviting state such as no
  /// reviews yet; otherwise it stays neutral.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent ? AppColors.primaryLight : AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: accent ? AppColors.primary : AppColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            KeepAllText(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 2),
              KeepAllText(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Static placeholders shaped like review cards while the first load runs.
/// They do not animate, so the screen settles in tests and stays calm.
class _ReviewListSkeleton extends StatelessWidget {
  const _ReviewListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '리뷰를 불러오고 있어요',
      child: ExcludeSemantics(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _SkeletonCard(wide: index.isEven),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.wide});

  /// Alternates the last line's length so the cards do not look stamped.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(width: 72, height: 14),
                  SizedBox(height: 6),
                  _SkeletonBar(width: 112, height: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _SkeletonBar(width: 84, height: 20, radius: 6),
          const SizedBox(height: 12),
          const _SkeletonBar(height: 12),
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: wide ? 0.72 : 0.5,
            child: const _SkeletonBar(height: 12),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    this.width,
    required this.height,
    this.radius = AppRadii.pill,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
