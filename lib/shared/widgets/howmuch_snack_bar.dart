import 'package:flutter/material.dart';

import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/core/theme/app_tokens.dart';

/// Visual intent for transient in-app feedback.
enum HowmuchSnackBarTone { info, success, warning, error }

/// Product-wide replacement for the raw Material [SnackBar].
///
/// It keeps the familiar [ScaffoldMessenger] lifecycle while applying the
/// Howmuch visual language: a compact raised surface, redundant status icon,
/// clear type hierarchy, a reachable dismiss control, and safe spacing above
/// the floating bottom navigation when requested.
class HowmuchSnackBar extends SnackBar {
  factory HowmuchSnackBar({
    Key? key,
    required Widget content,
    HowmuchSnackBarTone? tone,
    String? title,
    bool aboveNavigation = false,
    Duration? duration,
  }) {
    return HowmuchSnackBar._(
      key: key,
      content: content,
      tone: tone ?? _legacyToneFor(content),
      title: title,
      aboveNavigation: aboveNavigation,
      duration: duration,
    );
  }

  HowmuchSnackBar._({
    super.key,
    required Widget content,
    required this.tone,
    this.title,
    this.aboveNavigation = false,
    Duration? duration,
  }) : super(
         content: _HowmuchSnackBarSurface(
           content: content,
           tone: tone,
           title: title,
         ),
         backgroundColor: Colors.transparent,
         elevation: 0,
         behavior: SnackBarBehavior.floating,
         padding: EdgeInsets.zero,
         margin: EdgeInsets.fromLTRB(
           AppSpacing.sm,
           0,
           AppSpacing.sm,
           aboveNavigation ? 112 : AppSpacing.sm,
         ),
         hitTestBehavior: HitTestBehavior.deferToChild,
         dismissDirection: DismissDirection.horizontal,
         duration:
             duration ??
             (tone == HowmuchSnackBarTone.error
                 ? const Duration(milliseconds: 4800)
                 : tone == HowmuchSnackBarTone.warning
                 ? const Duration(milliseconds: 4200)
                 : const Duration(milliseconds: 3200)),
       );

  factory HowmuchSnackBar.success({
    Key? key,
    required Widget content,
    String? title,
    bool aboveNavigation = false,
    Duration? duration,
  }) {
    return HowmuchSnackBar._(
      key: key,
      content: content,
      tone: HowmuchSnackBarTone.success,
      title: title,
      aboveNavigation: aboveNavigation,
      duration: duration,
    );
  }

  factory HowmuchSnackBar.warning({
    Key? key,
    required Widget content,
    String? title,
    bool aboveNavigation = false,
    Duration? duration,
  }) {
    return HowmuchSnackBar._(
      key: key,
      content: content,
      tone: HowmuchSnackBarTone.warning,
      title: title,
      aboveNavigation: aboveNavigation,
      duration: duration,
    );
  }

  factory HowmuchSnackBar.error({
    Key? key,
    required Widget content,
    String? title,
    bool aboveNavigation = false,
    Duration? duration,
  }) {
    return HowmuchSnackBar._(
      key: key,
      content: content,
      tone: HowmuchSnackBarTone.error,
      title: title,
      aboveNavigation: aboveNavigation,
      duration: duration,
    );
  }

  /// Keeps migrated legacy call sites semantically useful while new code uses
  /// the explicit success/warning/error constructors.
  static HowmuchSnackBarTone _legacyToneFor(Widget content) {
    if (content is! Text) return HowmuchSnackBarTone.info;
    final message = content.data ?? '';

    if (_containsAny(message, const ['실패', '오류', '못했', '거부', '네트워크', '불가'])) {
      return HowmuchSnackBarTone.error;
    }
    if (_containsAny(message, const [
      '완료',
      '저장했',
      '접수',
      '추가했',
      '해제했',
      '삭제했',
      '로그인했',
      '복사했',
      '불러왔',
      '신청했',
      '등록되었',
    ])) {
      return HowmuchSnackBarTone.success;
    }
    if (_containsAny(message, const [
      '입력',
      '확인',
      '필요',
      '최대',
      '선택',
      '제공하지',
      '찾을 수 없',
      '정보가 없',
      '다르게',
    ])) {
      return HowmuchSnackBarTone.warning;
    }
    return HowmuchSnackBarTone.info;
  }

  static bool _containsAny(String message, List<String> fragments) {
    return fragments.any(message.contains);
  }

  final HowmuchSnackBarTone tone;
  final String? title;
  final bool aboveNavigation;
}

class _HowmuchSnackBarSurface extends StatelessWidget {
  const _HowmuchSnackBarSurface({
    required this.content,
    required this.tone,
    this.title,
  });

  static const double _maxWidth = 398;

  final Widget content;
  final HowmuchSnackBarTone tone;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final visuals = _SnackBarVisuals.forTone(tone);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceOverlay,
              borderRadius: BorderRadius.circular(AppRadii.overlay),
              border: Border.all(color: visuals.borderColor),
              boxShadow: AppElevation.overlay,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: reduceMotion ? Duration.zero : AppMotion.fast,
                    curve: AppMotion.standard,
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: visuals.iconSurface,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      visuals.icon,
                      size: 21,
                      color: visuals.iconColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? visuals.defaultTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                            letterSpacing: -0.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        DefaultTextStyle.merge(
                          style: const TextStyle(
                            color: AppColors.textBody,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          child: content,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '알림 닫기',
                    onPressed: () =>
                        ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                    constraints: const BoxConstraints.tightFor(
                      width: AppSizes.compactTouchTarget,
                      height: AppSizes.compactTouchTarget,
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      hoverColor: AppColors.background,
                      highlightColor: AppColors.background,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 19),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SnackBarVisuals {
  const _SnackBarVisuals({
    required this.icon,
    required this.iconColor,
    required this.iconSurface,
    required this.borderColor,
    required this.defaultTitle,
  });

  factory _SnackBarVisuals.forTone(HowmuchSnackBarTone tone) {
    return switch (tone) {
      HowmuchSnackBarTone.info => const _SnackBarVisuals(
        icon: Icons.info_outline_rounded,
        iconColor: AppColors.primary,
        iconSurface: AppColors.primaryLight,
        borderColor: Color(0x332563EB),
        defaultTitle: '알려드려요',
      ),
      HowmuchSnackBarTone.success => const _SnackBarVisuals(
        icon: Icons.check_rounded,
        iconColor: AppColors.success,
        iconSurface: AppColors.successLight,
        borderColor: Color(0x33047857),
        defaultTitle: '완료했어요',
      ),
      HowmuchSnackBarTone.warning => const _SnackBarVisuals(
        icon: Icons.priority_high_rounded,
        iconColor: AppColors.warning,
        iconSurface: AppColors.warningLight,
        borderColor: Color(0x33C2410C),
        defaultTitle: '확인해주세요',
      ),
      HowmuchSnackBarTone.error => const _SnackBarVisuals(
        icon: Icons.close_rounded,
        iconColor: AppColors.error,
        iconSurface: AppColors.errorLight,
        borderColor: Color(0x33EF4444),
        defaultTitle: '처리하지 못했어요',
      ),
    };
  }

  final IconData icon;
  final Color iconColor;
  final Color iconSurface;
  final Color borderColor;
  final String defaultTitle;
}
