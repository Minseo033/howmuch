import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class MyReportsPendingScreen extends StatelessWidget {
  const MyReportsPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '3-B',
      title: '내 제보 · 검토 중',
      owner: '오태관',
      feature: '커뮤니티',
    );
  }
}
