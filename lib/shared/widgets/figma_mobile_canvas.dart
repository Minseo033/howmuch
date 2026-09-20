import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A canvas widget that renders the Figma-designed mobile UI.
///
/// **App (iOS/Android)**: Scales the 375px design to fill the screen width.
/// **Mobile Web (≤480px)**: Uses 100% viewport width, height fills available space.
/// **Desktop Web (>480px)**: Centers the content at max 430px width.
///
/// Selected presentation surfaces can opt into the wider web shell. This is
/// intentionally opt-in so detail/forms screens keep their Figma mobile
/// geometry while the map and search surfaces can use tablet/desktop space.
class FigmaMobileCanvas extends StatelessWidget {
  const FigmaMobileCanvas({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.outerBackgroundColor = const Color(0xFFFCFBF7),
    this.wideWebLayout = false,
  });

  /// Design reference width from Figma (375px)
  static const double designWidth = 375.45452880859375;

  /// Design reference height from Figma (800px)
  static const double designHeight = 800.0;

  /// Legacy alias kept for backward compatibility
  static const double width = designWidth;

  /// Legacy alias kept for backward compatibility
  static const double height = designHeight;

  /// Max width for desktop web centering
  static const double maxWebWidth = 430.0;

  /// Breakpoint and max width for the presentation web shell.
  static const double wideWebBreakpoint = 768.0;
  static const double maxWideWebWidth = 1180.0;

  /// Keeps narrow or zoomed browser viewports inside their actual bounds.
  static double webContentWidthFor(
    double viewportWidth, {
    double maxWidth = maxWebWidth,
  }) {
    if (!viewportWidth.isFinite || viewportWidth <= 0) return 0;
    if (!maxWidth.isFinite || maxWidth <= 0) return 0;
    return math.min(viewportWidth, maxWidth);
  }

  /// Returns the width used by the opt-in wide web shell.
  static double wideWebContentWidthFor(double viewportWidth) {
    return webContentWidthFor(viewportWidth, maxWidth: maxWideWebWidth);
  }

  final Widget child;
  final Color backgroundColor;
  final Color outerBackgroundColor;
  final bool wideWebLayout;

  /// Returns true when running on the web platform.
  static bool get _isWeb => kIsWeb;

  /// Returns the effective logical width used by the canvas for a given context.
  /// On web, this matches the actual viewport width (capped at maxWebWidth).
  /// On native mobile, this is always the design width (375px).
  static double logicalWidthOf(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    return webContentWidthFor(viewportWidth);
  }

  /// Returns the scale factor applied to the canvas for a given context.
  /// On both web and native responsive canvas, logical scale is 1.0.
  static double designScaleFor(BuildContext context) {
    return 1.0;
  }

  /// Returns safe padding translated into the logical coordinate space of the canvas.
  static EdgeInsets designSafePaddingOf(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.viewPadding;
    final systemGestureInsets = mediaQuery.systemGestureInsets;

    if (_isWeb) {
      // On web, viewPadding is usually 0. Return zero safe insets.
      return EdgeInsets.zero;
    }

    return EdgeInsets.fromLTRB(
      padding.left,
      padding.top,
      padding.right,
      math.max(padding.bottom, systemGestureInsets.bottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: outerBackgroundColor,
      // 입력 화면에서는 키보드가 콘텐츠를 가리지 않도록 실제 viewport 높이를
      // 반영한다. 각 화면의 scroll view가 남은 영역에서 자연스럽게 스크롤된다.
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return _buildLayout(context, constraints);
        },
      ),
    );
  }

  /// Canvas layout: uses real viewport width (≤430px) on mobile/narrow screens,
  /// and centers the content at max 430px width on desktop/tablet/landscape
  /// without clipping, miniaturization, or horizontal overflow while preserving desktop max-width shell.
  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final viewportWidth = constraints.maxWidth;
    final viewportHeight = constraints.maxHeight;

    // On mobile web: fill 100% width
    final useWideWebLayout =
        wideWebLayout && _isWeb && viewportWidth >= wideWebBreakpoint;
    final contentWidth = webContentWidthFor(
      viewportWidth,
      maxWidth: useWideWebLayout ? maxWideWebWidth : maxWebWidth,
    );
    final showDesktopFrame = viewportWidth > maxWebWidth;

    return Align(
      alignment: Alignment.topCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: showDesktopFrame
              ? const Border.symmetric(
                  vertical: BorderSide(color: Color(0x1A94A3B8)),
                )
              : null,
          boxShadow: showDesktopFrame
              ? const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: SizedBox(
          width: contentWidth,
          height: viewportHeight,
          child: ClipRect(
            child: ColoredBox(
              color: backgroundColor,
              child: _isWeb
                  ? _WebSafeArea(child: SizedBox.expand(child: child))
                  : SizedBox.expand(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps child in a SafeArea on web to respect browser chrome (address bar, etc.)
class _WebSafeArea extends StatelessWidget {
  const _WebSafeArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // On web, use MediaQuery padding for any notch/system UI insets.
    // This handles iOS Safari bottom bar, etc.
    final padding = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
      child: child,
    );
  }
}
