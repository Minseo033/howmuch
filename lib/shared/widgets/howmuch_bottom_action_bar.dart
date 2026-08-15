import 'package:flutter/material.dart';
import 'package:howmuch/core/constants/app_sizes.dart';

class HowmuchBottomActionBar extends StatelessWidget {
  const HowmuchBottomActionBar({
    super.key,
    required this.safeBottom,
    required this.child,
    this.backgroundColor = Colors.white,
    this.showTopBorder = true,
    this.topPadding = 12,
    this.bottomPadding = 20,
  });

  static const double buttonHeight = 46.0;

  static double heightFor(
    double safeBottom, {
    double topPadding = 12,
    double bottomPadding = 20,
    double contentHeight = buttonHeight,
  }) {
    return topPadding + contentHeight + bottomPadding + safeBottom;
  }

  final double safeBottom;
  final Widget child;
  final Color backgroundColor;
  final bool showTopBorder;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.horizontalPadding,
        topPadding,
        AppSizes.horizontalPadding,
        safeBottom + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: showTopBorder
            ? const Border(
                top: BorderSide(color: Color(0xFFE5E7EB), width: .909),
              )
            : null,
      ),
      child: child,
    );
  }
}
