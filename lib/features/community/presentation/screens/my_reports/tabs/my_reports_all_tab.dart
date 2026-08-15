import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart';

import "package:flutter_riverpod/flutter_riverpod.dart";

class MyReportsAllTab extends ConsumerWidget {
  const MyReportsAllTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleReports = ref.watch(myReportDataProvider);

    return Column(
      children: [
        ...visibleReports.map((report) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ReportCard(
              report: report,
              isCompact: true,
              onTap: () => context.push(
                '${AppRoutes.reportDetailV2}?id=${report.id}',
                extra: report.source,
              ),
              onPrimaryTap: () {
                if (report.filter == ReportFilter.approved) {
                  context.go(AppRoutes.home);
                  return;
                }
                if (report.filter == ReportFilter.needsEdit) {
                  context.push(AppRoutes.reportCreate, extra: report.source);
                  return;
                }
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
