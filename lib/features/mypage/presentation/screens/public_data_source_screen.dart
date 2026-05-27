import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class PublicDataSourceScreen extends StatelessWidget {
  const PublicDataSourceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '5-D',
      title: '공공데이터 출처',
      owner: '김민서',
      feature: '마이페이지',
    );
  }
}
