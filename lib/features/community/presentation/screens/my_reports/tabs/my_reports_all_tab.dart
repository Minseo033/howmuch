import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart';

class MyReportsAllTab extends StatelessWidget {
  const MyReportsAllTab({super.key});

  @override
  Widget build(BuildContext context) {
    final visibleReports = reportsData;

    return Column(
      children: [
        ...reportsData.map(
          (report) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ReportCard(
              report: report,
              isCompact: true,
              onTap: () => context.push('${AppRoutes.reportDetailV2}?id=${report.id}'),
              onPrimaryTap: () {
                if (report.filter == ReportFilter.approved) {
                  context.go(AppRoutes.home);
                  return;
                }
                if (report.filter == ReportFilter.needsEdit) {
                  context.push(AppRoutes.reportCreate);
                  return;
                }
                context.push('${AppRoutes.reportDetailV2}?id=${report.id}');
              },
            ),
          ),
        ),
      ],
    );

  }
}
