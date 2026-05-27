import 'package:flutter/material.dart';

class HowmuchButton extends StatelessWidget {
  const HowmuchButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = isPrimary
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon ?? Icons.check),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon ?? Icons.arrow_forward),
            label: Text(label),
          );

    final styled = ButtonTheme(
      alignedDropdown: true,
      child: SizedBox(height: 48, child: button),
    );

    if (!expand) {
      return styled;
    }

    return SizedBox(width: double.infinity, child: styled);
  }
}
