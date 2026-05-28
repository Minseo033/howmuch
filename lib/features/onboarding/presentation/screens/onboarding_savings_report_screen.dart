import 'package:flutter/material.dart';
import 'package:howmuch/features/onboarding/presentation/screens/onboarding_nearby_screen.dart';

class OnboardingSavingsReportScreen extends StatelessWidget {
  const OnboardingSavingsReportScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const OnboardingNearbyScreen(initialStep: 1);
}
