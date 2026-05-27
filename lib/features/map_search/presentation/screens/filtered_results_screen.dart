import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class FilteredResultsScreen extends StatelessWidget {
  const FilteredResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '2-3',
      title: '필터 적용 결과',
      owner: '김다나',
      feature: '검색',
    );
  }
}
