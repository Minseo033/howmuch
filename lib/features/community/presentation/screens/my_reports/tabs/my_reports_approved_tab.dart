import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/my_reports_v2_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/widgets/my_reports_widgets.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/recommendation/presentation/state/ai_chat_service.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/store/presentation/screens/store_detail_screen.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';

import "package:flutter_riverpod/flutter_riverpod.dart";

AiMapRecommendationResult buildApprovedReportMapResult(
  UserReportStatus report, {
  Store? currentStore,
}) {
  UserReportMenuPrice menu(int index) => index < report.menuPrices.length
      ? report.menuPrices[index]
      : const UserReportMenuPrice(menu: '', price: '');
  final store =
      currentStore ??
      Store(
        id: report.storeId,
        storeName: report.store,
        address: report.address,
        phoneNumber: '',
        industry: report.category,
        menu1: menu(0).menu,
        price1: menu(0).price,
        free1: menu(0).free,
        menu2: menu(1).menu,
        price2: menu(1).price,
        free2: menu(1).free,
        menu3: menu(2).menu,
        price3: menu(2).price,
        free3: menu(2).free,
        menu4: menu(3).menu,
        price4: menu(3).price,
        free4: menu(3).free,
        latitude: report.latitude,
        longitude: report.longitude,
        source: report.resolution == 'NEW_STORE' ? 'USER' : 'UNKNOWN',
      );
  return AiMapRecommendationResult(
    storeIds: report.storeId.isEmpty ? const [] : [report.storeId],
    stores: [store],
    queryText: report.store,
    origin: MapResultOrigin.approvedReport,
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
            text: '내 제보가 동네 가격 정보를 더 풍성하게 만들었어요.',
            color: MyReportsV2Screen.green,
            backgroundColor: Color(0xFFFFF0E6),
            singleLine: true,
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
              onPrimaryTap: () async {
                Store? latest;
                try {
                  if (report.source.storeId.isNotEmpty) {
                    latest = await ref.refresh(
                      currentStoreDetailProvider(report.source.storeId).future,
                    );
                  }
                } catch (_) {
                  if (report.source.isExistingStoreReport) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        HowmuchSnackBar(
                          content: Text('대상 매장 정보를 불러오지 못했어요. 다시 시도해주세요.'),
                        ),
                      );
                    }
                    return;
                  }
                }
                if (!context.mounted) return;
                context.go(
                  AppRoutes.home,
                  extra: buildApprovedReportMapResult(
                    report.source,
                    currentStore: latest,
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}
