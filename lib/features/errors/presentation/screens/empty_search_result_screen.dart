import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/shared/widgets/status_message.dart';

class EmptySearchResultScreen extends StatelessWidget {
  const EmptySearchResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('7-2 검색 결과 0건')),
      body: StatusMessage(
        icon: Icons.search_off,
        title: '검색 결과가 없어요',
        message: '필터를 줄이거나 다른 지역, 메뉴명으로 다시 검색해보세요.',
        actionLabel: '필터 초기화',
        onAction: () => context.go(AppRoutes.home),
        secondaryLabel: '홈으로 이동',
        onSecondaryAction: () => context.go(AppRoutes.home),
      ),
    );
  }
}
