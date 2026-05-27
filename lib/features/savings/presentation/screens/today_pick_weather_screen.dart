import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class TodayPickWeatherScreen extends StatelessWidget {
  const TodayPickWeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '4-3',
      title: '오늘의 픽 · 날씨 추천',
      owner: '오태관',
      feature: '절약 리포트',
    );
  }
}
