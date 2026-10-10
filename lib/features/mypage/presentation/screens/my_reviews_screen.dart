import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/core/theme/app_tokens.dart';
import 'package:howmuch/features/auth/presentation/state/login_flow.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:howmuch/shared/widgets/login_required_state.dart';

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
    // The list is shared by the whole app. Opening the screen reloads it so
    // reviews written elsewhere (another device, the web) show up; the last
    // list stays on screen meanwhile (QA #11).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(myReviewsProvider.notifier).loadReviews(force: true);
    });
  }

  Future<void> _refresh() async {
    await ref.read(myReviewsProvider.notifier).loadReviews(force: true);
    if (!mounted) return;
    final reviews = ref.read(myReviewsProvider);
    // A failed refresh keeps the list, so say that it is not up to date.
    if (reviews.hasError && reviews.hasValue) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          HowmuchSnackBar(
            content: const Text('내 리뷰를 새로고침하지 못했어요. 잠시 후 다시 시도해주세요.'),
          ),
        );
    }
  }

  /// Login opens on top of this screen and comes back here, as a member or
  /// still as a guest. The list follows the login state (see [build]); a load
  /// that failed while login was still finishing is asked for again.
  Future<void> _logIn() async {
    await openLoginFlow(context);
    if (!mounted || !ApiClient.isAuthenticated) return;
    if (ref.read(myReviewsProvider).hasError) {
      await ref.read(myReviewsProvider.notifier).loadReviews(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Every login state change replaces the list with one that nothing loads:
    // the ones while login is open on top of this screen (a new account that
    // leaves profile setup is a guest again) and a login that finishes after
    // the visitor left it. Load it for whoever is here: the account's
    // reviews, or the login prompt for a guest.
    ref.listen(myReviewsProvider.notifier, (_, notifier) {
      notifier.loadReviews(force: true);
    });
    final reviewsState = ref.watch(myReviewsProvider);
    final reviewCount = reviewsState.valueOrNull?.length ?? 0;

    return FigmaMobileCanvas(
      backgroundColor: AppColors.surface,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: CustomAppBar(
          title: '내 리뷰',
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                // Text.rich picks up the app font; RichText did not.
                child: Text.rich(
                  TextSpan(
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
            // An error with a loaded list keeps showing that list.
            skipError: true,
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
              : _FlatRefresh(
                  onRefresh: _refresh,
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
              child: Text.rich(
                TextSpan(
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
    // No stats above these: zeros would read as no reviews written.
    if (error is MyReviewsAuthRequiredException) {
      // A login-required state needs a way to log in.
      return LoginRequiredState(
        description: '내가 작성한 리뷰는 로그인 후 확인할 수 있어요.',
        actionLabel: '로그인하기',
        onAction: _logIn,
      );
    }
    return _LoadError(
      onRetry: () =>
          ref.read(myReviewsProvider.notifier).loadReviews(force: true),
    );
  }

  Widget _buildEmptyState() {
    return _FlatRefresh(
      onRefresh: _refresh,
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (review.storeSource == 'GOV')
                const StatusBadge(type: BadgeType.government)
              else if (review.storeSource == 'USER')
                const StatusBadge(type: BadgeType.user)
              else
                const Text(
                  '출처 확인 필요',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
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
                        : AppColors.disabled,
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
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textBody,
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: child,
    );
  }
}

/// Pull to refresh as a flat pale-blue disc: no Material shadow, and it stays
/// visible over the white cards it slides across.
class _FlatRefresh extends StatelessWidget {
  const _FlatRefresh({required this.onRefresh, required this.child});

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.primaryLight,
      elevation: 0,
      child: child,
    );
  }
}

/// The app's load error: what failed, what to do, and a retry.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: .909),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.warning,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '내 리뷰를 불러오지 못했어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '잠시 후 다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                // 40 tall like the other error blocks, with a 48px tap area.
                minimumSize: const Size(140, 40),
                tapTargetSize: MaterialTapTargetSize.padded,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Noto Sans KR',
                  fontFamilyFallback: ['Noto Sans KR'],
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('다시 불러오기'),
            ),
          ],
        ),
      ),
    );
  }
}
