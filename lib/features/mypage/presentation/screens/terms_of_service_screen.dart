import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '5-K',
      title: '서비스 이용약관',
      owner: '김민서',
      feature: '마이페이지',
    );
  }
}
