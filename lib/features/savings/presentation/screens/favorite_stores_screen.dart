import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/screen_placeholder.dart';

class FavoriteStoresScreen extends StatelessWidget {
  const FavoriteStoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      figmaId: '4-5',
      title: '찜한 매장',
      owner: '오태관',
      feature: '절약 리포트',
    );
  }
}
