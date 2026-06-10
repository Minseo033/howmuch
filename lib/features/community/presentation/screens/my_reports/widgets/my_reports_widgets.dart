import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';

class TopBanner extends StatelessWidget {
  const TopBanner({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontFamily: "Inter",
                fontFamilyFallback: [
                  "Noto Sans KR",
                  "Apple SD Gothic Neo",
                  "AppleGothic",
                  "Arial Unicode MS",
                  "Malgun Gothic",
                  "sans-serif",
                ],
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateBox extends StatelessWidget {
  const EmptyStateBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE5E7EB), width: 0.909),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F6FA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '검토 중인 제보가 없어요',
            style: TextStyle(
              color: Color(0xFF0A0A0A),
              fontFamily: "Inter",
              fontFamilyFallback: [
                "Noto Sans KR",
                "Apple SD Gothic Neo",
                "AppleGothic",
                "Arial Unicode MS",
                "Malgun Gothic",
                "sans-serif",
              ],
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '새 제보를 등록해보세요',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontFamily: "Inter",
              fontFamilyFallback: [
                "Noto Sans KR",
                "Apple SD Gothic Neo",
                "AppleGothic",
                "Arial Unicode MS",
                "Malgun Gothic",
                "sans-serif",
              ],
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.report,
    required this.onTap,
    required this.onPrimaryTap,
    this.isCompact = false,
  });

  final MyReportData report;
  final VoidCallback onTap;
  final VoidCallback onPrimaryTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFFE5E7EB), width: .909),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusBadge(report: report),
                  Text(
                    report.date,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontFamily: "Inter",
                      fontFamilyFallback: [
                        "Noto Sans KR",
                        "Apple SD Gothic Neo",
                        "AppleGothic",
                        "Arial Unicode MS",
                        "Malgun Gothic",
                        "sans-serif",
                      ],
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                report.title,
                style: const TextStyle(
                  color: Color(0xFF0A0A0A),
                  fontFamily: "Inter",
                  fontFamilyFallback: [
                    "Noto Sans KR",
                    "Apple SD Gothic Neo",
                    "AppleGothic",
                    "Arial Unicode MS",
                    "Malgun Gothic",
                    "sans-serif",
                  ],
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '대표 메뉴',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontFamily: "Inter",
                      fontFamilyFallback: [
                        "Noto Sans KR",
                        "Apple SD Gothic Neo",
                        "AppleGothic",
                        "Arial Unicode MS",
                        "Malgun Gothic",
                        "sans-serif",
                      ],
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    report.menu,
                    style: const TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontFamily: "Inter",
                      fontFamilyFallback: [
                        "Noto Sans KR",
                        "Apple SD Gothic Neo",
                        "AppleGothic",
                        "Arial Unicode MS",
                        "Malgun Gothic",
                        "sans-serif",
                      ],
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              if (!isCompact && report.filter == ReportFilter.pending) ...[
                const SizedBox(height: 16),
                const SizedBox(height: 40, child: MiniProgressSteps()),
              ],
              if (!isCompact && report.notice != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFF97316),
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          report.notice!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9A3412),
                            fontFamily: "Inter",
                            fontFamilyFallback: [
                              "Noto Sans KR",
                              "Apple SD Gothic Neo",
                              "AppleGothic",
                              "Arial Unicode MS",
                              "Malgun Gothic",
                              "sans-serif",
                            ],
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!isCompact && report.filter == ReportFilter.approved) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.location_on,
                        color: Color(0xFF10B981),
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '지도에 사용자 제보 매장으로 표시 중',
                            maxLines: 1,
                            style: TextStyle(
                              color: Color(0xFF047857),
                              fontFamily: "Inter",
                              fontFamilyFallback: [
                                "Noto Sans KR",
                                "Apple SD Gothic Neo",
                                "AppleGothic",
                                "Arial Unicode MS",
                                "Malgun Gothic",
                                "sans-serif",
                              ],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        child: const Text(
                          '상세보기',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontFamily: "Inter",
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onPrimaryTap,
                        icon: const Icon(Icons.location_on_outlined, size: 14),
                        label: const Text(
                          '지도에서 보기',
                          style: TextStyle(
                            fontFamily: "Inter",
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (!isCompact &&
                  report.actionLabel != null &&
                  report.filter != ReportFilter.approved) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: report.actionWidth,
                    height: 33.991,
                    child: SmallActionButton(
                      label: report.actionLabel!,
                      color: report.actionColor,
                      icon: report.actionIcon,
                      onTap: onPrimaryTap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.report});

  final MyReportData report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: report.badgeWidth,
      height: 20.994,
      decoration: BoxDecoration(
        color: report.badgeBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: report.badgeDotColor ?? report.badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            report.status,
            style: TextStyle(
              color: report.badgeTextColor ?? report.badgeColor,
              fontFamily: "Inter",
              fontFamilyFallback: [
                "Noto Sans KR",
                "Apple SD Gothic Neo",
                "AppleGothic",
                "Arial Unicode MS",
                "Malgun Gothic",
                "sans-serif",
              ],
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class SmallActionButton extends StatelessWidget {
  const SmallActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: "Inter",
                fontFamilyFallback: [
                  "Noto Sans KR",
                  "Apple SD Gothic Neo",
                  "AppleGothic",
                  "Arial Unicode MS",
                  "Malgun Gothic",
                  "sans-serif",
                ],
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniProgressSteps extends StatelessWidget {
  const MiniProgressSteps({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      StepData('접수 완료', 0, Color(0xFF10B981), true),
      StepData('정보 확인 중', 1, Color(0xFFF97316), false),
      StepData('승인 대기', 2, Color(0xFFCBD5E1), false),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const circleSize = 16.0;
        const connectorInset = 4.0;
        const connectorHeight = 2.0;
        const labelTop = 20.0;
        final stepWidth = constraints.maxWidth / items.length;
        final circleTop = 0.0;
        final connectorTop = circleTop + (circleSize - connectorHeight) / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < items.length - 1; index++)
              Positioned(
                left:
                    stepWidth * index +
                    stepWidth / 2 +
                    circleSize / 2 +
                    connectorInset,
                top: connectorTop,
                width: stepWidth - circleSize - connectorInset * 2,
                height: connectorHeight,
                child: ColoredBox(
                  color: index < 1
                      ? const Color(0xFF10B981)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            for (var index = 0; index < items.length; index++)
              Positioned(
                left: stepWidth * index,
                top: circleTop,
                width: stepWidth,
                child: Center(
                  child: Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      color: items[index].color,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: items[index].done
                        ? const Icon(
                            Icons.check_rounded,
                            size: 10,
                            color: Colors.white,
                          )
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            for (var index = 0; index < items.length; index++)
              Positioned(
                left: stepWidth * index,
                top: labelTop,
                width: stepWidth,
                child: Text(
                  items[index].label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: index == 1
                        ? const Color(0xFFF97316)
                        : (items[index].done
                              ? Color(0xFF0F172A)
                              : Color(0xFF64748B)),
                    fontSize: 9.5,
                    fontWeight: index == 1 ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class StepData {
  const StepData(this.label, this.index, this.color, this.done);

  final String label;
  final int index;
  final Color color;
  final bool done;
}

enum ReportFilter { all, pending, approved, needsEdit, rejected }

class MyReportData {
  const MyReportData({
    required this.id,
    required this.filter,
    required this.status,
    required this.date,
    required this.title,
    required this.menu,
    required this.badgeBackground,
    required this.badgeColor,
    this.badgeDotColor,
    this.badgeTextColor,
    required this.badgeWidth,
    required this.height,
    this.notice,
    this.actionLabel,
    this.actionColor = const Color(0xFF2563EB),
    this.actionIcon = Icons.location_on_outlined,
    this.actionTop = 102.95,
    this.actionWidth = 120.185,
  });

  final String id;
  final ReportFilter filter;
  final String status;
  final String date;
  final String title;
  final String menu;
  final Color badgeBackground;
  final Color badgeColor;
  final Color? badgeDotColor;
  final Color? badgeTextColor;
  final double badgeWidth;
  final double height;
  final String? notice;
  final String? actionLabel;
  final Color actionColor;
  final IconData actionIcon;
  final double actionTop;
  final double actionWidth;
}

final myReportDataProvider = Provider<List<MyReportData>>((ref) {
  final riverpodReports = ref.watch(userReportsProvider);
  return riverpodReports.map((r) {
    ReportFilter filter = ReportFilter.all;
    if (r.status.contains('검토')) filter = ReportFilter.pending;
    else if (r.status.contains('승인')) filter = ReportFilter.approved;
    else if (r.status.contains('보완')) filter = ReportFilter.needsEdit;
    else if (r.status.contains('반려')) filter = ReportFilter.rejected;

    double height = 108.778;
    if (filter == ReportFilter.approved) height = 154.759;
    else if (filter == ReportFilter.needsEdit) height = 194.134;

    return MyReportData(
      id: r.id,
      filter: filter,
      status: r.status,
      date: '2026.05.12', // dummy date
      title: r.store,
      menu: r.menu,
      badgeBackground: Color(r.statusBg),
      badgeColor: Color(r.textColor),
      badgeWidth: 70.497,
      height: height,
      notice: filter == ReportFilter.needsEdit ? '메뉴판 사진이 흐려 가격 확인이 어려워요' : null,
      actionLabel: filter == ReportFilter.approved ? '지도에서 보기' : (filter == ReportFilter.needsEdit ? '수정하기' : null),
      actionColor: filter == ReportFilter.needsEdit ? const Color(0xFFF97316) : const Color(0xFF2563EB),
      actionIcon: filter == ReportFilter.needsEdit ? Icons.edit_outlined : Icons.location_on_outlined,
      actionTop: 142.33,
      actionWidth: 120.185,
    );
  }).toList();
});

const reportsData = [
  MyReportData(
    id: '1',
    filter: ReportFilter.pending,
    status: '검토 중',
    date: '2026.05.12',
    title: '골목밥상',
    menu: '제육덮밥 6,000원',
    badgeBackground: Color(0xFFFEF3C7),
    badgeColor: Color(0xFF92400E),
    badgeWidth: 60.497,
    height: 108.778,
  ),
  MyReportData(
    id: '2',
    filter: ReportFilter.approved,
    status: '승인 완료',
    date: '2026.05.09',
    title: '동네카페',
    menu: '아메리카노 2,000원',
    badgeBackground: Color(0xFFE8F8F1),
    badgeColor: Color(0xFF10B981),
    badgeWidth: 70.497,
    height: 154.759,
    actionLabel: '지도에서 보기',
    actionColor: Color(0xFF2563EB),
    actionIcon: Icons.location_on_outlined,
  ),
  MyReportData(
    id: '3',
    filter: ReportFilter.needsEdit,
    status: '보완 요청',
    date: '2026.05.08',
    title: '착한김밥',
    menu: '김밥 2,500원',
    badgeBackground: Color(0xFFFEF3C7),
    badgeColor: Color(0xFFF97316),
    badgeDotColor: Color(0xFFF59E0B),
    badgeTextColor: Color(0xFF92400E),
    badgeWidth: 70.497,
    height: 194.134,
    notice: '메뉴판 사진이 흐려 가격 확인이 어려워요',
    actionLabel: '수정하기',
    actionColor: Color(0xFF2563EB),
    actionIcon: Icons.edit_outlined,
    actionTop: 142.33,
    actionWidth: 120.185,
  ),
];
