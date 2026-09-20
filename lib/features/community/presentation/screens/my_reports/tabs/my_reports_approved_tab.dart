import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/my_reports_v2_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/store/store_model.dart';

import "package:flutter_riverpod/flutter_riverpod.dart";

AiMapRecommendationResult buildApprovedReportMapResult(
  UserReportStatus report,
) {
  final firstMenu = report.menuPrices.isNotEmpty
      ? report.menuPrices.first
      : null;
  final store = Store(
    id: report.storeId,
    storeName: report.store,
    address: report.address,
    phoneNumber: '',
    industry: report.category,
    menu1: firstMenu?.menu ?? report.menu,
    price1: firstMenu?.price ?? '',
    menu2: '',
    price2: '',
    menu3: '',
    price3: '',
    menu4: '',
    price4: '',
    latitude: report.latitude,
    longitude: report.longitude,
    source: 'USER',
  );
  return AiMapRecommendationResult(
    storeIds: report.storeId.isEmpty ? const [] : [report.storeId],
    stores: [store],
    queryText: report.store,
  );
}

class MyReportsApprovedTab extends ConsumerWidget {
  const MyReportsApprovedTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleReports = ref
        .watch(myReportDataProvider)
        .where((report) => report.filter == ReportFilter.approved)
        .toList();

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
                context.go(
                  AppRoutes.home,
                  extra: buildApprovedReportMapResult(report.source),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}
