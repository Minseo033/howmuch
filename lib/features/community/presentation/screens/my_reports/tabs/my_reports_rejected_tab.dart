import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart';

import "package:flutter_riverpod/flutter_riverpod.dart";
class MyReportsRejectedTab extends ConsumerWidget {
  const MyReportsRejectedTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleReports = ref.watch(myReportDataProvider)
        .where((report) => report.filter == ReportFilter.rejected)
        .toList();

    return Column(
      children: [
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
      ],
    );
  }
}
