import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class MyReportDetailScreen extends StatelessWidget {
  const MyReportDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '3-D',
      title: '내 제보 상세',
      owner: '오태관',
      feature: '커뮤니티',
    );
  }
}
