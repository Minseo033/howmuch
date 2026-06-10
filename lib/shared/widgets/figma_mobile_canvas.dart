import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FigmaMobileCanvas extends StatelessWidget {
  const FigmaMobileCanvas({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.outerBackgroundColor = const Color(0xFFF4F6FA),
  });

  static const width = 375.45452880859375;
  static const height = 800.0;

  final Widget child;
  final Color backgroundColor;
  final Color outerBackgroundColor;

  static double designScaleFor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fitScale = math.min(size.width / width, size.height / height);

    return kIsWeb ? math.min(1.0, fitScale) : fitScale;
  }

  static EdgeInsets designSafePaddingOf(BuildContext context) {
    final scale = designScaleFor(context);
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.viewPadding;
    final systemGestureInsets = mediaQuery.systemGestureInsets;

    if (scale <= 0) {
      return EdgeInsets.zero;
    }

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
          final fitScale = math.min(
            constraints.maxWidth / width,
            constraints.maxHeight / height,
          );
          final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

          final scale = isMobile 
              ? constraints.maxWidth / width 
              : (kIsWeb ? math.min(1.0, fitScale) : fitScale);

          final scaledWidth = isMobile ? constraints.maxWidth : width * scale;
          final scaledHeight = isMobile ? constraints.maxHeight : height * scale;

          final logicalWidth = width;
          final logicalHeight = isMobile ? constraints.maxHeight / scale : height;

          final alignment = kIsWeb ? Alignment.center : const Alignment(0, -1);

          return Align(
            alignment: alignment,
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
        },
      ),
    );
  }
}
