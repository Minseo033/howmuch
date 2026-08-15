import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A canvas widget that renders the Figma-designed mobile UI.
///
/// **App (iOS/Android)**: Scales the 375px design to fill the screen width.
/// **Mobile Web (≤480px)**: Uses 100% viewport width, height fills available space.
/// **Desktop Web (>480px)**: Centers the content at max 430px width.
class FigmaMobileCanvas extends StatelessWidget {
  const FigmaMobileCanvas({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.outerBackgroundColor = const Color(0xFFF4F6FA),
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

  final Widget child;
  final Color backgroundColor;
  final Color outerBackgroundColor;

  /// Returns true when running on the web platform.
  static bool get _isWeb => kIsWeb;



  /// Returns the effective logical width used by the canvas for a given context.
  /// On web, this matches the actual viewport width (capped at maxWebWidth).
  /// On native mobile, this is always the design width (375px).
  static double logicalWidthOf(BuildContext context) {
    if (!_isWeb) return designWidth;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    return viewportWidth.clamp(320.0, maxWebWidth);
  }

  /// Returns the scale factor applied to the canvas for a given context.
  static double designScaleFor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    if (_isWeb) {
      // On web, we use the actual viewport width - no scaling applied.
      // Scale is 1.0 relative to actual pixels.
      return 1.0;
    }

    final isMobile = (defaultTargetPlatform == TargetPlatform.iOS ||
                      defaultTargetPlatform == TargetPlatform.android) &&
                     size.width < 600;

    if (isMobile) {
      return size.width / designWidth;
    }

    final fitScale = math.min(size.width / designWidth, size.height / designHeight);
    return fitScale;
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

    final scale = designScaleFor(context);
    if (scale <= 0) return EdgeInsets.zero;

    return EdgeInsets.fromLTRB(
      padding.left / scale,
      padding.top / scale,
      padding.right / scale,
      math.max(padding.bottom, systemGestureInsets.bottom) / scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: outerBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_isWeb) {
            return _buildWebLayout(context, constraints);
          } else {
            return _buildNativeLayout(context, constraints);
          }
        },
      ),
    );
  }

  /// Web layout: uses real viewport width, centers on desktop.
  Widget _buildWebLayout(BuildContext context, BoxConstraints constraints) {
    final viewportWidth = constraints.maxWidth;
    final viewportHeight = constraints.maxHeight;

    // On mobile web: fill 100% width
    final contentWidth = viewportWidth.clamp(320.0, maxWebWidth);

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: contentWidth,
        height: viewportHeight,
        child: ColoredBox(
          color: backgroundColor,
          child: _WebSafeArea(
            child: child,
          ),
        ),
      ),
    );
  }

  /// Native app layout: scales the 375px design to fill screen width.
  Widget _buildNativeLayout(BuildContext context, BoxConstraints constraints) {
    final fitScale = math.min(
      constraints.maxWidth / designWidth,
      constraints.maxHeight / designHeight,
    );

    final isMobileDevice = defaultTargetPlatform == TargetPlatform.iOS ||
                           defaultTargetPlatform == TargetPlatform.android;
    final isMobile = isMobileDevice && constraints.maxWidth < 600;

    final scale = isMobile
        ? constraints.maxWidth / designWidth
        : fitScale;

    final scaledWidth = isMobile ? constraints.maxWidth : designWidth * scale;
    final scaledHeight = isMobile ? constraints.maxHeight : designHeight * scale;

    final logicalWidth = designWidth;
    final logicalHeight = isMobile
        ? constraints.maxHeight / scale
        : designHeight;

    return Align(
      alignment: const Alignment(0, -1),
      child: SizedBox(
        width: scaledWidth,
        height: scaledHeight,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: logicalWidth,
            height: logicalHeight,
            child: ColoredBox(color: backgroundColor, child: child),
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
      padding: EdgeInsets.only(
        top: padding.top,
        bottom: padding.bottom,
      ),
      child: child,
    );
  }
}
