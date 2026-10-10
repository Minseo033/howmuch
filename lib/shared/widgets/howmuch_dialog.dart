import 'package:flutter/material.dart';
import 'package:howmuch/core/theme/app_colors.dart';

/// A compact, keyboard-safe dialog shared by account actions.
class HowmuchDialog extends StatelessWidget {
  const HowmuchDialog({
    super.key,
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel = '취소',
    this.onCancel,
    this.cancelEnabled = true,
    this.child,
    this.destructive = false,
    this.confirmKey,
    this.confirmColor,
    this.confirmForeground,
    this.cancelFlex = 1,
    this.confirmFlex = 2,
  });

  final String title;
  final String description;
  final String confirmLabel;
  final String cancelLabel;

  /// Called by the confirm button. Null disables it, for example while the
  /// action runs or when there is nothing to act on.
  final VoidCallback? onConfirm;

  /// Called by the cancel button instead of closing the dialog route. A
  /// dialog shown inline on a page uses this to leave the page itself.
  final VoidCallback? onCancel;

  /// Whether the cancel button can be pressed, e.g. false while the confirmed
  /// action is still running.
  final bool cancelEnabled;

  final Widget? child;
  final bool destructive;
  final Key? confirmKey;
  final Color? confirmColor;
  final Color? confirmForeground;
  final int cancelFlex;
  final int confirmFlex;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.primary,
          selectionColor: AppColors.primary.withValues(alpha: 0.18),
          selectionHandleColor: AppColors.primary,
        ),
      ),
      child: AlertDialog(
        semanticLabel: '$title. $description',
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        scrollable: true,
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.5,
            height: 1.3,
          ),
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.muted,
                ),
              ),
              if (child != null) ...[const SizedBox(height: 24), child!],
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                flex: cancelFlex,
                child: TextButton(
                  autofocus: true,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: AppColors.textBody,
                    backgroundColor: AppColors.surface,
                    disabledForegroundColor: AppColors.textMuted,
                    disabledBackgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: cancelEnabled
                      ? (onCancel ?? () => Navigator.of(context).pop())
                      : null,
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: confirmFlex,
                child: FilledButton(
                  key: confirmKey,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor:
                        confirmColor ??
                        (destructive ? AppColors.errorText : AppColors.primary),
                    foregroundColor: confirmForeground ?? AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Noto Sans KR',
                      fontFamilyFallback: ['Noto Sans KR'],
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: onConfirm,
                  child: Text(confirmLabel, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
