import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/errors/presentation/screens/store_info_report_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';

/// 기존 매장의 메뉴 가격을 바꾸자는 제보(인상·인하·삭제·신규 메뉴)인지 확인합니다.
bool isPriceChangeReport(UserReportStatus report) =>
    !report.isInformationReport && report.changeType.trim().isNotEmpty;

/// 제보 유형에 맞는 수정 화면을 엽니다.
///
/// 가격 변동 제보를 신규 매장 작성 화면으로 열면 변동 유형과 대상 매장 없이
/// 저장돼 신규 매장 제보로 바뀝니다. 그래서 가격 변동 화면에서 같은 ID로
/// 수정하고, 정보 신고는 정보 신고 화면에서 수정합니다.
void openReportEditor(BuildContext context, UserReportStatus report) {
  if (report.isApproved) return;
  if (report.isInformationReport) {
    context.push(
      AppRoutes.storeInfoReport,
      extra: StoreInfoReportTarget(initialReport: report),
    );
  } else if (isPriceChangeReport(report)) {
    context.push(AppRoutes.priceChangeReport, extra: report);
  } else {
    context.push(AppRoutes.reportCreate, extra: report);
  }
}
