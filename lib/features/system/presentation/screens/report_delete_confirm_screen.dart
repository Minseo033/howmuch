import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/figma_mobile_canvas.dart';

class ReportDeleteConfirmScreen extends ConsumerStatefulWidget {
  const ReportDeleteConfirmScreen({super.key, this.report});

  final UserReportStatus? report;

  static const red = Color(0xFFE53935);
  static const redBg = Color(0xFFFEE2E2);
  static const redInk = Color(0xFF7F1D1D);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const surface = Color(0xFFF4F6FA);
  static const border = Color(0xFFE5E7EB);
  static const fontFamily = 'Inter';
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
      backgroundColor: Colors.white,
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
              child: SizedBox(
                width: math.min(
                  327.4715881347656,
                  FigmaMobileCanvas.logicalWidthOf(context) - 48,
                ),
                height: 317.96875,
                child: _DeleteDialog(
                  report: widget.report,
                  isDeleting: _isDeleting,
                  onCancel: close,
                  onDelete: widget.report == null ? null : _deleteReport,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReport() async {
    final report = widget.report;
    if (report == null || _isDeleting) return;

    setState(() => _isDeleting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reportServiceProvider).deleteReport(report.id);
      if (!mounted) return;

      ref.read(userReportsProvider.notifier).removeReport(report.id);
      final profile = ref.read(userProfileProvider);
      ref.read(userProfileProvider.notifier).state = profile.copyWith(
        reportCount: math.max(0, profile.reportCount - 1),
      );

      context.go(AppRoutes.myReportsV2);
      messenger.showSnackBar(
        SnackBar(content: Text('${report.store} 제보를 삭제했어요.')),
      );
    } on ReportServiceException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      setState(() => _isDeleting = false);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('제보 삭제 중 오류가 발생했습니다.')),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 60,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            const Positioned(
              left: 135.738525390625,
              top: 27.9970703125,
              width: 55.99431610107422,
              height: 55.99431610107422,
              child: _DeleteIcon(),
            ),
            const Positioned(
              left: 88.89208984375,
              top: 99.986328125,
              width: 149.6732940673828,
              height: 25.49715805053711,
              child: Text(
                '제보를 삭제할까요?',
                textAlign: TextAlign.center,
                style: _dialogTitleText,
              ),
            ),
            Positioned(
              left: 20,
              top: 129.474609375,
              width: 287.4715881347656,
              height: 19.488636016845703,
              child: Text(
                _subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _dialogSubtitleText,
              ),
            ),
            const Positioned(
              left: 20,
              top: 164.95703125,
              width: 287.4715881347656,
              height: 77.61363220214844,
              child: _WarningPanel(),
            ),
            Positioned(
              left: 0,
              top: 262.5712890625,
              width: 327.4715881347656,
              height: 55.39772415161133,
              child: _DialogActions(
                isDeleting: isDeleting,
                onCancel: onCancel,
                onDelete: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    final value = report;
    if (value == null) return '제보 정보를 찾을 수 없어요.';
    final menu = value.menu.trim();
    return menu.isEmpty ? value.store : '${value.store} · $menu';
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
  const _WarningPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ReportDeleteConfirmScreen.redBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Stack(
        children: [
          Positioned(
            left: 11.988525390625,
            top: 11.9892578125,
            child: Icon(
              Icons.warning_amber_rounded,
              color: ReportDeleteConfirmScreen.red,
              size: 13,
            ),
          ),
          Positioned(
            left: 32.98291015625,
            top: 10,
            width: 242.49998474121094,
            height: 57.6136360168457,
            child: Text(
              '삭제 후에는 되돌릴 수 없어요.\n승인 완료된 제보는 지도에서도 즉시 제거됩니다.',
              style: _warningText,
            ),
          ),
        ],
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

const _warningText = TextStyle(
  color: ReportDeleteConfirmScreen.redInk,
  fontFamily: ReportDeleteConfirmScreen.fontFamily,
  fontFamilyFallback: ReportDeleteConfirmScreen.fontFallback,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  height: 1.6,
);
