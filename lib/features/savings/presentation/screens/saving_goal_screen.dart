import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class SavingGoalScreen extends StatelessWidget {
  const SavingGoalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '4-7',
      title: '절약 목표 설정',
      owner: '오태관',
      feature: '절약 리포트',
    );
  }
}
