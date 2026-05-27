import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class EmptySearchResultScreen extends StatelessWidget {
  const EmptySearchResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '7-2',
      title: '검색 결과 0건',
      owner: '김민서',
      feature: '공통 상태',
    );
  }
}
