import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/theme/app_colors.dart';
import 'package:howmuch/features/recommendation/presentation/state/recommendation_radius.dart';

class RecommendationRadiusButton extends ConsumerWidget {
  const RecommendationRadiusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = ref.watch(recommendationRadiusProvider);
    return OutlinedButton.icon(
      onPressed: () async {
        final selected = await showModalBottomSheet<int>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '추천 거리',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      'AI 채팅과 오늘의 픽에 함께 적용돼요. 기존 대화는 그대로 두고 다음 질문부터 적용해요.',
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: 15,
                      itemBuilder: (_, index) {
                        final meters = (index + 1) * 1000;
                        return Semantics(
                          selected: meters == radius,
                          child: ListTile(
                            title: Text('${index + 1}km 이내'),
                            trailing: meters == radius
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () => Navigator.pop(sheetContext, meters),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (selected != null) {
          final saved = await ref
              .read(recommendationRadiusProvider.notifier)
              .setRadius(selected);
          if (!saved && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('추천 거리를 이번 접속에 적용했어요. 기기 저장을 허용하면 다음에도 유지돼요.'),
              ),
            );
          }
        }
      },
      icon: const Icon(Icons.near_me_outlined, size: 16),
      label: Text('${radius ~/ 1000}km 이내'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }
}
