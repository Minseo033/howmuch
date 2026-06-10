import 'package:flutter/material.dart';

enum BadgeType { government, user }

class StatusBadge extends StatelessWidget {
  final BadgeType type;

  const StatusBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String text;

    if (type == BadgeType.government) {
      bgColor = const Color(0xFFEEF2FF); // 연한 파란색
      textColor = const Color(0xFF4A68F6); // 짙은 파란색
      text = '정부 인증';
    } else {
      bgColor = const Color(0xFFFFF0E6); // 연한 주황색
      textColor = const Color(0xFFF27E22); // 주황색
      text = '사용자 제보';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
