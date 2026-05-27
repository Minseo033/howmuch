import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class OnboardingNearbyScreen extends StatelessWidget {
  const OnboardingNearbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '1-1',
      title: '온보딩 · 주변 착한가격업소',
      owner: '김민서',
      feature: '온보딩',
    );
  }
}
