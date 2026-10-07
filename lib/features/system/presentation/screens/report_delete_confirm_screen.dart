import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_snack_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class ReportDeleteConfirmScreen extends ConsumerStatefulWidget {
  const ReportDeleteConfirmScreen({super.key, this.report});

  final UserReportStatus? report;

  static const red = Color(0xFFEF4444);
  static const redBg = Color(0xFFFEE2E2);
  static const redInk = Color(0xFFEF4444);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const surface = Color(0xFFF4F6FA);
  static const border = Color(0xFFE5E7EB);
  static const fontFamily = 'Noto Sans KR';
  static const fontFallback = [
    'Noto Sans KR',
    'Apple SD Gothic Neo',
    'AppleGothic',
    'Arial Unicode MS',
    'Malgun Gothic',
    'sans-serif',
  ];

  @override
  ConsumerState<ReportDeleteConfirmScreen> createState() =>
      _ReportDeleteConfirmScreenState();
}

class _ReportDeleteConfirmScreenState
    extends ConsumerState<ReportDeleteConfirmScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final topOffset = FigmaMobileCanvas.designSafePaddingOf(context).top;

    void close() {
      if (_isDeleting) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.myReportsV2);
      }
    }

    return FigmaMobileCanvas(
      backgroundColor: const Color(0xFFF4F6FA),
      // 삭제 요청 중에는 시스템 뒤로가기로 닫지 않습니다.
      child: PopScope(
        canPop: !_isDeleting,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: topOffset,
              right: 0,
              bottom: 0,
              child: ColoredBox(color: Colors.black.withValues(alpha: .4)),
            ),
            Positioned.fill(
              top: topOffset,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                    width: math.min(
                      327.4715881347656,
                      FigmaMobileCanvas.logicalWidthOf(context) - 48,
                    ),
                    child: _DeleteDialog(
                      report: widget.report,
                      isDeleting: _isDeleting,
                      onCancel: close,
                      onDelete: widget.report == null ? null : _deleteReport,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteReport() async {
    final report = widget.report;
    if (report == null || _isDeleting) return;

    setState(() => _isDeleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final reportsNotifier = ref.read(userReportsProvider.notifier);
    final profileNotifier = ref.read(userProfileProvider.notifier);
    try {
      await ref.read(reportServiceProvider).deleteReport(report.id);
      // 화면이 먼저 닫혔더라도 삭제가 끝났으면 내 제보 목록과 개수를 갱신합니다.
      reportsNotifier.removeReport(report.id);
      final profile = profileNotifier.state;
      profileNotifier.state = profile.copyWith(
        reportCount: math.max(0, profile.reportCount - 1),
      );
      if (!mounted) return;

      context.go(AppRoutes.myReportsV2);
      messenger.showSnackBar(
        HowmuchSnackBar(content: Text('${report.store} 제보를 삭제했어요.')),
      );
    } on ReportServiceException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(HowmuchSnackBar(content: Text(error.message)));
      setState(() => _isDeleting = false);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        HowmuchSnackBar(content: Text('제보 삭제 중 오류가 발생했습니다.')),
      );
      setState(() => _isDeleting = false);
    }
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({
    required this.report,
    required this.isDeleting,
    required this.onCancel,
    required this.onDelete,
  });

  final UserReportStatus? report;
  final bool isDeleting;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 60,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        // 좌표를 고정하지 않고 위에서부터 쌓아 320px 화면에서도 버튼이 잘리지 않습니다.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: SizedBox(
                        width: 55.99431610107422,
                        height: 55.99431610107422,
                        child: _DeleteIcon(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: _dialogTitleText,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _dialogSubtitleText,
                    ),
                    for (final line in _details) ...[
                      const SizedBox(height: 2),
                      Text(
                        line,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _dialogDetailText,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _WarningPanel(report: report),
                  ],
                ),
              ),
            ),
            _DialogActions(
              isDeleting: isDeleting,
              onCancel: onCancel,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String get _title {
    final value = report;
    return value == null ? '제보를 삭제할까요?' : '${value.kindLabel}를 삭제할까요?';
  }

  String get _subtitle {
    final value = report;
    if (value == null) return '제보 정보를 찾을 수 없어요.';
    return value.store.trim().isEmpty ? '매장명 없음' : value.store;
  }

  /// 같은 매장의 다른 제보와 구분되도록 제보 내용과 날짜·처리 상태를 보여 줍니다.
  List<String> get _details {
    final value = report;
    if (value == null) return const [];
    final content = value.isPriceChangeReport
        ? value.summaryText
        : value.summaryValue.trim().isEmpty
        ? ''
        : '${value.summaryLabel} ${value.summaryValue}';
    final meta = [
      value.createdDateLabel,
      value.displayStatus,
    ].where((part) => part.isNotEmpty).join(' · ');
    return [content, meta].where((line) => line.isNotEmpty).toList();
  }
}

class _DeleteIcon extends StatelessWidget {
  const _DeleteIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: ReportDeleteConfirmScreen.redBg,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: ReportDeleteConfirmScreen.red,
        size: 24,
      ),
    );
  }
}

class _WarningPanel extends StatelessWidget {
  const _WarningPanel({this.report});
  final UserReportStatus? report;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ReportDeleteConfirmScreen.redBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.warning_amber_rounded,
                color: ReportDeleteConfirmScreen.red,
                size: 13,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                report?.deletionWarning ?? '삭제 후에는 되돌릴 수 없어요.',
                style: _warningText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.isDeleting,
    required this.onCancel,
    required this.onDelete,
  });

  final bool isDeleting;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: ReportDeleteConfirmScreen.border, width: .909),
        ),
      ),
      child: Row(
        children: [
          _DialogAction(
            label: '취소',
            color: ReportDeleteConfirmScreen.muted,
            onTap: isDeleting ? null : onCancel,
            showDivider: true,
          ),
          _DialogAction(
            label: isDeleting ? '삭제 중...' : '삭제하기',
            color: ReportDeleteConfirmScreen.red,
            bold: true,
            onTap: isDeleting ? null : onDelete,
            showProgress: isDeleting,
          ),
        ],
      ),
    );
  }
}

class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.bold = false,
    this.showDivider = false,
    this.showProgress = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool bold;
  final bool showDivider;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 54.4886360168457,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: showDivider
                  ? const Border(
                      right: BorderSide(
                        color: ReportDeleteConfirmScreen.border,
                        width: .909,
                      ),
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showProgress) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: onTap == null && !showProgress
                        ? color.withValues(alpha: .45)
                        : color,
                    fontFamily: ReportDeleteConfirmScreen.fontFamily,
                    fontFamilyFallback: ReportDeleteConfirmScreen.fontFallback,
                    fontSize: 15,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _dialogTitleText = TextStyle(
  color: ReportDeleteConfirmScreen.ink,
  fontFamily: ReportDeleteConfirmScreen.fontFamily,
  fontFamilyFallback: ReportDeleteConfirmScreen.fontFallback,
  fontSize: 17,
  fontWeight: FontWeight.w800,
  height: 1.5,
);

const _dialogSubtitleText = TextStyle(
  color: ReportDeleteConfirmScreen.muted,
  fontFamily: ReportDeleteConfirmScreen.fontFamily,
  fontFamilyFallback: ReportDeleteConfirmScreen.fontFallback,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _dialogDetailText = TextStyle(
  color: ReportDeleteConfirmScreen.muted,
  fontFamily: ReportDeleteConfirmScreen.fontFamily,
  fontFamilyFallback: ReportDeleteConfirmScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const _warningText = TextStyle(
  color: ReportDeleteConfirmScreen.redInk,
  fontFamily: ReportDeleteConfirmScreen.fontFamily,
  fontFamilyFallback: ReportDeleteConfirmScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.6,
);
