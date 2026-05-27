import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/admin/presentation/state/admin_state.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';
import 'package:howmuch/shared/widgets/howmuch_section.dart';

class AdminReportReviewScreen extends ConsumerWidget {
  const AdminReportReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminReportsProvider);
    final filter = ref.watch(reportStatusFilterProvider);
    final filtered = filter == null
        ? reports
        : reports.where((item) => item.status == filter).toList();

    return HowmuchScaffold(
      title: '6-1 관리자 제보 검토',
      subtitle: '사용자 제보를 검토하고 승인 또는 반려 상태로 변경합니다.',
      actions: [
        TextButton(
          onPressed: () => context.go(AppRoutes.adminInquiryReview),
          child: const Text('문의 검토'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusFilters(
            selected: filter,
            onSelected: (value) {
              ref.read(reportStatusFilterProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 14),
          SectionTitle('제보 ${filtered.length}건'),
          const SizedBox(height: 8),
          for (final report in filtered) ...[
            _ReportCard(
              report: report,
              onStatusChanged: (status) {
                ref.read(adminReportsProvider.notifier).state = reports
                    .map(
                      (item) => item.id == report.id
                          ? item.copyWith(status: status)
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

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({required this.selected, required this.onSelected});

  final ReviewStatus? selected;
  final ValueChanged<ReviewStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('전체'),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final status in [
          ReviewStatus.pending,
          ReviewStatus.approved,
          ReviewStatus.rejected,
        ])
          ChoiceChip(
            label: Text(status.label),
            selected: selected == status,
            onSelected: (_) => onSelected(status),
          ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onStatusChanged});

  final AdminReport report;
  final ValueChanged<ReviewStatus> onStatusChanged;

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
                  report.storeName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Chip(label: Text(report.status.label)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${report.id} · ${report.category} · ${report.address}'),
          const SizedBox(height: 10),
          Text(report.message),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onStatusChanged(ReviewStatus.rejected),
                  icon: const Icon(Icons.close),
                  label: const Text('반려'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onStatusChanged(ReviewStatus.approved),
                  icon: const Icon(Icons.check),
                  label: const Text('승인'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
