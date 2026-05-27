import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class PriceChangeReportScreen extends StatelessWidget {
  const PriceChangeReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '2-10',
      title: '가격 변동 제보',
      owner: '김다나',
      feature: '매장',
    );
  }
}
