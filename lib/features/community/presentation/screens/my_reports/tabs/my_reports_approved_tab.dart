import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/my_reports_v2_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart';

class MyReportsApprovedTab extends StatelessWidget {
  const MyReportsApprovedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final visibleReports = reportsData.where((report) => report.filter == ReportFilter.approved).toList();

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: TopBanner(
            icon: Icons.auto_awesome,
            text: '고마워요!\n내 제보가 동네 가격 정보를\n더 풍성하게 만들었어요.',
            color: MyReportsV2Screen.green,
            backgroundColor: Color(0xFFECFDF5),
          ),
        ),
        ...visibleReports.map(
          (report) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ReportCard(
              report: report,
              onTap: () => context.push('${AppRoutes.reportDetailV2}?id=${report.id}'),
              onPrimaryTap: () {
                context.go(AppRoutes.home);
              },
            ),
          ),
        ),
      ],
    );

  }
}
