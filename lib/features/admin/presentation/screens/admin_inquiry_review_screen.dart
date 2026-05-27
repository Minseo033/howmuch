import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/admin/presentation/state/admin_state.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';
import 'package:howmuch/shared/widgets/howmuch_section.dart';

class AdminInquiryReviewScreen extends ConsumerWidget {
  const AdminInquiryReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiries = ref.watch(adminInquiriesProvider);
    final filter = ref.watch(inquiryStatusFilterProvider);
    final filtered = filter == null
        ? inquiries
        : inquiries.where((item) => item.status == filter).toList();

    return HowmuchScaffold(
      title: '6-2 관리자 문의 검토',
      subtitle: '사용자 문의를 확인하고 답변 완료 상태로 변경합니다.',
      actions: [
        TextButton(
          onPressed: () => context.go(AppRoutes.adminReportReview),
          child: const Text('제보 검토'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: filter == null,
                onSelected: (_) {
                  ref.read(inquiryStatusFilterProvider.notifier).state = null;
                },
              ),
              for (final status in [
                ReviewStatus.pending,
                ReviewStatus.answered,
              ])
                ChoiceChip(
                  label: Text(status.label),
                  selected: filter == status,
                  onSelected: (_) {
                    ref.read(inquiryStatusFilterProvider.notifier).state =
                        status;
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          SectionTitle('문의 ${filtered.length}건'),
          const SizedBox(height: 8),
          for (final inquiry in filtered) ...[
            _InquiryCard(
              inquiry: inquiry,
              onAnswered: () {
                ref.read(adminInquiriesProvider.notifier).state = inquiries
                    .map(
                      (item) => item.id == inquiry.id
                          ? item.copyWith(status: ReviewStatus.answered)
                          : item,
                    )
                    .toList();
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _InquiryCard extends StatelessWidget {
  const _InquiryCard({required this.inquiry, required this.onAnswered});

  final AdminInquiry inquiry;
  final VoidCallback onAnswered;

  @override
  Widget build(BuildContext context) {
    return HowmuchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  inquiry.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Chip(label: Text(inquiry.status.label)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${inquiry.id} · ${inquiry.author}'),
          const SizedBox(height: 10),
          Text(inquiry.message),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: inquiry.status == ReviewStatus.answered
                ? null
                : onAnswered,
            icon: const Icon(Icons.mark_email_read),
            label: const Text('답변 완료 처리'),
          ),
        ],
      ),
    );
  }
}
