import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class MyInquiriesScreen extends ConsumerWidget {
  const MyInquiriesScreen({super.key});

  static const _headerHeight = 48.877838134765625;
  static const _fontFamily = 'Inter';
  static const _fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safePadding = FigmaMobileCanvas.designSafePaddingOf(context);
    final inquiriesAsync = ref.watch(myInquiriesProvider);

    return FigmaMobileCanvas(
      backgroundColor: AppColors.surface,
      child: Stack(
        children: [
          Positioned.fill(
            top: safePadding.top + _headerHeight,
            child: inquiriesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, _) => _LoadError(
                requiresLogin:
                    error is InquiryApiException && error.isUnauthorized,
                onRetry: () => ref.invalidate(myInquiriesProvider),
              ),
              data: (inquiries) => _InquiryList(
                inquiries: inquiries,
                bottomPadding: safePadding.bottom,
                onRefresh: () async => ref.invalidate(myInquiriesProvider),
              ),
            ),
          ),
          _InquiriesHeader(
            topOffset: safePadding.top,
            onBack: () {
              if (GoRouter.of(context).canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.mypage);
              }
            },
            onCreate: () => context.go(AppRoutes.inquiry),
          ),
        ],
      ),
    );
  }
}

class _InquiriesHeader extends StatelessWidget {
  const _InquiriesHeader({
    required this.topOffset,
    required this.onBack,
    required this.onCreate,
  });

  final double topOffset;
  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      height: MyInquiriesScreen._headerHeight + topOffset,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: .909),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: topOffset,
              width: 72,
              height: MyInquiriesScreen._headerHeight,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 24,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 72,
              right: 72,
              top: 11.98876953125 + topOffset,
              child: const IgnorePointer(
                child: Text(
                  '내 문의 내역',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.black,
                    fontFamily: MyInquiriesScreen._fontFamily,
                    fontFamilyFallback: MyInquiriesScreen._fontFallback,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: topOffset,
              width: 48,
              height: MyInquiriesScreen._headerHeight,
              child: Tooltip(
                message: '문의 작성',
                child: IconButton(
                  onPressed: onCreate,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.ink,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InquiryList extends StatelessWidget {
  const _InquiryList({
    required this.inquiries,
    required this.bottomPadding,
    required this.onRefresh,
  });

  final List<Inquiry> inquiries;
  final double bottomPadding;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (inquiries.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(20, 132, 20, 32 + bottomPadding),
          children: const [
            Icon(Icons.forum_outlined, color: AppColors.disabled, size: 48),
            SizedBox(height: 14),
            Text(
              '등록한 문의가 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ink,
                fontFamily: MyInquiriesScreen._fontFamily,
                fontFamilyFallback: MyInquiriesScreen._fontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '궁금한 내용은 문의하기에서 남겨주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontFamily: MyInquiriesScreen._fontFamily,
                fontFamilyFallback: MyInquiriesScreen._fontFallback,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(20, 18, 20, 32 + bottomPadding),
        itemCount: inquiries.length + 1,
        separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 14 : 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _InquirySummary(count: inquiries.length);
          }
          return _InquiryCard(inquiry: inquiries[index - 1]);
        },
      ),
    );
  }
}

class _InquirySummary extends StatelessWidget {
  const _InquirySummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '문의 내역',
          style: TextStyle(
            color: AppColors.ink,
            fontFamily: MyInquiriesScreen._fontFamily,
            fontFamilyFallback: MyInquiriesScreen._fontFallback,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count건',
          style: const TextStyle(
            color: AppColors.primary,
            fontFamily: MyInquiriesScreen._fontFamily,
            fontFamilyFallback: MyInquiriesScreen._fontFallback,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.requiresLogin, required this.onRetry});

  final bool requiresLogin;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              requiresLogin ? '로그인이 필요해요' : '문의 내역을 불러오지 못했어요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontFamily: MyInquiriesScreen._fontFamily,
                fontFamilyFallback: MyInquiriesScreen._fontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              requiresLogin ? '로그인한 뒤 다시 확인해주세요.' : '잠시 후 다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontFamily: MyInquiriesScreen._fontFamily,
                fontFamilyFallback: MyInquiriesScreen._fontFallback,
                fontSize: 13,
              ),
            ),
            if (!requiresLogin) ...[
              const SizedBox(height: 18),
              TextButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ],
        ),
      ),
    );
  }
}

class _InquiryCard extends StatelessWidget {
  const _InquiryCard({required this.inquiry});

  final Inquiry inquiry;

  @override
  Widget build(BuildContext context) {
    final answered = inquiry.isAnswered;
    final answer = inquiry.answer?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.question_answer_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inquiry.title.isEmpty ? '제목 없는 문의' : inquiry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontFamily: MyInquiriesScreen._fontFamily,
                        fontFamilyFallback: MyInquiriesScreen._fontFallback,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${inquiry.category} · ${_formatDate(inquiry.createdAt)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontFamily: MyInquiriesScreen._fontFamily,
                        fontFamilyFallback: MyInquiriesScreen._fontFallback,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(answered: answered),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            inquiry.content,
            style: const TextStyle(
              color: AppColors.textBody,
              fontFamily: MyInquiriesScreen._fontFamily,
              fontFamilyFallback: MyInquiriesScreen._fontFallback,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (inquiry.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: inquiry.imageUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    inquiry.imageUrls[index],
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 76,
                      height: 76,
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (answered && answer != null && answer.isNotEmpty)
            _AnswerPanel(answer: answer, answeredAt: inquiry.answeredAt)
          else
            const _WaitingPanel(),
        ],
      ),
    );
  }

  static String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}.$month.$day';
  }
}

class _AnswerPanel extends StatelessWidget {
  const _AnswerPanel({required this.answer, required this.answeredAt});

  final String answer;
  final String? answeredAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.support_agent_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                '답변',
                style: TextStyle(
                  color: AppColors.primary,
                  fontFamily: MyInquiriesScreen._fontFamily,
                  fontFamilyFallback: MyInquiriesScreen._fontFallback,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                _InquiryCard._formatDate(answeredAt),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontFamily: MyInquiriesScreen._fontFamily,
                  fontFamilyFallback: MyInquiriesScreen._fontFallback,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: const TextStyle(
              color: AppColors.textBody,
              fontFamily: MyInquiriesScreen._fontFamily,
              fontFamilyFallback: MyInquiriesScreen._fontFallback,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.schedule_outlined, size: 16, color: AppColors.warning),
          SizedBox(width: 7),
          Text(
            '답변을 준비하고 있어요.',
            style: TextStyle(
              color: AppColors.warningDark,
              fontFamily: MyInquiriesScreen._fontFamily,
              fontFamilyFallback: MyInquiriesScreen._fontFallback,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.answered});

  final bool answered;

  @override
  Widget build(BuildContext context) {
    final color = answered ? AppColors.primary : AppColors.warningDark;
    final background = answered
        ? AppColors.primaryLight
        : AppColors.warningLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        answered ? '답변 완료' : '답변 대기',
        style: TextStyle(
          color: color,
          fontFamily: MyInquiriesScreen._fontFamily,
          fontFamilyFallback: MyInquiriesScreen._fontFallback,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
