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
    final visibleReports = ref.watch(myReportDataProvider)
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
            backgroundColor: Color(0xFFEFF6FF),
          ),
        ),
        ...visibleReports.map(
          (report) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ReportCard(
              report: report,
              onTap: () =>
                  context.push('${AppRoutes.reportDetailV2}?id=${report.id}'),
              onPrimaryTap: () {
                context.push('${AppRoutes.reportDetailV2}?id=${report.id}');
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '이전 검토 내역',
            style: TextStyle(
              color: MyReportsV2Screen.muted,
              fontFamily: MyReportsV2Screen.fontFamily,
              fontFamilyFallback: MyReportsV2Screen.fontFallback,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const EmptyStateBox(),
      ],
    );
  }
}
