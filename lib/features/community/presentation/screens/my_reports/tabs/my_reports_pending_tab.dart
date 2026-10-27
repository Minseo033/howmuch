import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/my_reports_v2_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart';

import "package:flutter_riverpod/flutter_riverpod.dart";

class MyReportsPendingTab extends ConsumerWidget {
  const MyReportsPendingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleReports = ref
        .watch(myReportDataProvider)
        .where((report) => report.filter == ReportFilter.pending)
        .toList();

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: TopBanner(
            icon: Icons.access_time,
            text: '보통 1~3일 안에 검토가 완료돼요.',
            color: MyReportsV2Screen.blue,
            backgroundColor: Color(0xFFEEF2FF),
          ),
        ),
        ...visibleReports.map((report) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ReportCard(
              report: report,
              onTap: () => context.push(
                '${AppRoutes.reportDetailV2}?id=${report.id}',
                extra: report.source,
              ),
              onPrimaryTap: () {
                context.push(
                  '${AppRoutes.reportDetailV2}?id=${report.id}',
                  extra: report.source,
                );
              },
            ),
          );
        }),
      ],
    );
  }
}
