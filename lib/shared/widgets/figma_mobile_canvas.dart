import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A canvas widget that renders the Figma-designed mobile UI.
///
/// Content uses the real viewport width up to [maxWebWidth] and is centered
/// beyond that, on both the app and the web.
///
/// Selected presentation surfaces can opt into the wider web shell. This is
/// intentionally opt-in so detail/forms screens keep their Figma mobile
/// geometry while the map and search surfaces can use tablet/desktop space.
class FigmaMobileCanvas extends StatelessWidget {
  const FigmaMobileCanvas({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.outerBackgroundColor = const Color(0xFFF4F6FA),
    this.wideWebLayout = false,
  });

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

  /// Returns the effective logical width used by the canvas for a given context:
  /// the actual viewport width, capped at [maxWebWidth].
  static double logicalWidthOf(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    return webContentWidthFor(viewportWidth);
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

  /// Removes the part of the side insets that lies outside a centered column
  /// [sideOffset] away from each viewport edge.
  ///
  /// A landscape phone reports its notch insets (about 60 on each side) for
  /// the whole screen. The 430 column never reaches them, but a SafeArea
  /// inside it still reserved them and squeezed the store detail buttons
  /// (QA 10/7 #44).
  static MediaQueryData insetsInsideColumn(
    MediaQueryData data,
    double sideOffset,
  ) {
    if (sideOffset <= 0) return data;
    EdgeInsets trim(EdgeInsets insets) => insets.copyWith(
      left: math.max(0.0, insets.left - sideOffset),
      right: math.max(0.0, insets.right - sideOffset),
    );
    return data.copyWith(
      padding: trim(data.padding),
      viewPadding: trim(data.viewPadding),
      viewInsets: trim(data.viewInsets),
      systemGestureInsets: trim(data.systemGestureInsets),
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
    final contentWidth = useWideWebLayout
        ? wideWebContentWidthFor(viewportWidth)
        : webContentWidthFor(viewportWidth);
    final showDesktopFrame = viewportWidth > maxWebWidth;
    final sideOffset = math.max(0.0, (viewportWidth - contentWidth) / 2);
    final content = _isWeb
        ? _WebSafeArea(child: SizedBox.expand(child: child))
        : SizedBox.expand(child: child);

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
              // Always present, even without a side offset, so rotating the
              // device does not rebuild the screen and lose its state.
              child: MediaQuery(
                data: insetsInsideColumn(MediaQuery.of(context), sideOffset),
                child: content,
              ),
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
