import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/review_model.dart';

import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/figma_mobile_canvas.dart';
import '../../../../shared/widgets/status_badge.dart';

class MyReviewsScreen extends ConsumerStatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  ConsumerState<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends ConsumerState<MyReviewsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myReviewsProvider.notifier).loadReviews();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reviewsState = ref.watch(myReviewsProvider);
    final reviewCount = reviewsState.valueOrNull?.length ?? 0;

    return FigmaMobileCanvas(
      backgroundColor: AppColors.backgroundDark,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: CustomAppBar(
          title: '내 리뷰',
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: RichText(
                  text: TextSpan(
                    text: '총 ',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: '$reviewCount',
                        style: const TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: ' 개'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: reviewsState.when(
            loading: () => _buildLoadingBody(),
            error: (error, stackTrace) => _buildErrorBody(error),
            data: _buildReviewBody,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewBody(List<Review> reviews) {
    final averageRating = reviews.isEmpty
        ? 0.0
        : reviews.map((review) => review.stars).reduce((a, b) => a + b) /
              reviews.length;

    return Column(
      children: [
        _buildStatsHeader(reviews.length, averageRating),
        Expanded(
          child: reviews.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(myReviewsProvider.notifier)
                      .loadReviews(force: true),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    itemCount: reviews.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildReviewCard(reviews[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader(int count, double averageRating) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: _StatsCard(
              child: RichText(
                text: TextSpan(
                  text: '$count',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  children: const [
                    TextSpan(
                      text: ' 개 작성',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatsCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: AppColors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '평균 별점',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBody() {
    return Column(
      children: [
        _buildStatsHeader(0, 0),
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBody(Object error) {
    final authRequired = error is MyReviewsAuthRequiredException;
    final title = authRequired ? '로그인이 필요해요.' : '내 리뷰를 불러오지 못했어요.';
    final description = authRequired
        ? '내가 작성한 리뷰는 로그인 후 확인할 수 있어요.'
        : '잠시 후 다시 시도해주세요.';

    return Column(
      children: [
        _buildStatsHeader(0, 0),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    authRequired
                        ? Icons.lock_outline_rounded
                        : Icons.wifi_off_rounded,
                    color: AppColors.muted,
                    size: 44,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!authRequired)
                    OutlinedButton(
                      onPressed: () {
                        ref
                            .read(myReviewsProvider.notifier)
                            .loadReviews(force: true);
                      },
                      child: const Text('다시 불러오기'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(myReviewsProvider.notifier).loadReviews(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.rate_review_outlined, color: AppColors.muted, size: 48),
          SizedBox(height: 14),
          Text(
            '아직 작성한 리뷰가 없어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '방문한 매장에서 첫 리뷰를 남겨보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    final dateText = _formatDate(review.createdAt);
    final menuText = review.menu.isEmpty ? '방문 메뉴 정보 없음' : '방문: ${review.menu}';
    final storeName = review.storeName.isEmpty ? '매장 이름 없음' : review.storeName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const StatusBadge(type: BadgeType.user),
              Text(
                dateText,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            storeName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    Icons.star_rounded,
                    color: index < review.stars
                        ? AppColors.warning
                        : Colors.grey.shade300,
                    size: 16,
                  );
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  menuText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.trending_up, color: AppColors.success, size: 16),
              const SizedBox(width: 4),
              Text(
                '도움이 돼요 ${review.likes}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: child,
    );
  }
}
