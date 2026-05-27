import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class ReviewListScreen extends StatelessWidget {
  const ReviewListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '2-5',
      title: '리뷰 · 댓글 전체보기',
      owner: '김다나',
      feature: '매장',
    );
  }
}
