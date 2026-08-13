import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';

class MyInquiriesScreen extends ConsumerWidget {
  const MyInquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiriesAsync = ref.watch(myInquiriesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('내 문의 내역'),
        centerTitle: true,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: '뒤로 가기',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: '문의 작성',
            onPressed: () => context.go(AppRoutes.inquiry),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: inquiriesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => _LoadError(
          requiresLogin: error is InquiryApiException && error.isUnauthorized,
          onRetry: () => ref.invalidate(myInquiriesProvider),
        ),
        data: (inquiries) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(myInquiriesProvider),
          child: inquiries.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 150),
                    Icon(
                      Icons.question_answer_outlined,
                      size: 48,
                      color: AppColors.disabled,
                    ),
                    SizedBox(height: 14),
                    Center(
                      child: Text(
                        '등록한 문의가 없어요',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Center(
                      child: Text(
                        '궁금한 내용을 문의하기에서 남겨주세요.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, constraints) => ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    itemCount: inquiries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: _InquiryCard(inquiry: inquiries[index]),
                      ),
                    ),
                  ),
                ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              requiresLogin ? '로그인한 뒤 다시 확인해주세요.' : '인터넷 연결을 확인하고 다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            if (!requiresLogin) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  inquiry.title.isEmpty ? '제목 없는 문의' : inquiry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(answered: answered),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${inquiry.category}  |  접수 ${_formatDate(inquiry.createdAt)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text(
            '문의 내용',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            inquiry.content,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.border),
          ),
          if (answered && answer != null && answer.isNotEmpty) ...[
            const Text(
              '답변',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              answer,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '답변 ${_formatDate(inquiry.answeredAt)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ] else
            const Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 17,
                  color: AppColors.warning,
                ),
                SizedBox(width: 7),
                Text(
                  '답변을 기다리고 있어요.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
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
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}.$month.$day $hour:$minute';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.answered});

  final bool answered;

  @override
  Widget build(BuildContext context) {
    final color = answered ? AppColors.primary : AppColors.warning;
    final background = answered
        ? AppColors.primary.withValues(alpha: .1)
        : AppColors.warning.withValues(alpha: .12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        answered ? '답변 완료' : '답변 대기',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
