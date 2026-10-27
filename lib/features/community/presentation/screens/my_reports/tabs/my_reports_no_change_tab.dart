import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart';

import "package:flutter_riverpod/flutter_riverpod.dart";

/// 검토를 마쳤지만 매장 정보를 바꾸지 않은(NO_CHANGE) 제보 목록입니다.
class MyReportsNoChangeTab extends ConsumerWidget {
  const MyReportsNoChangeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleReports = ref
        .watch(myReportDataProvider)
        .where((report) => report.filter == ReportFilter.noChange)
        .toList();

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: TopBanner(
            icon: Icons.info_outline_rounded,
            text: '내용을 검토했지만 매장 정보는 바꾸지 않은 제보예요.',
            color: Color(0xFF374151),
            backgroundColor: Color(0xFFE5E7EB),
          ),
        ),
        ...visibleReports.map((report) {
          void openDetail() => context.push(
            '${AppRoutes.reportDetailV2}?id=${report.id}',
            extra: report.source,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ReportCard(
              report: report,
              onTap: openDetail,
              onPrimaryTap: openDetail,
            ),
          );
        }),
      ],
    );
  }
}
