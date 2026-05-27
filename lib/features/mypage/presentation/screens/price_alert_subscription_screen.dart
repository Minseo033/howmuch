import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/shared/widgets/howmuch_button.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';
import 'package:howmuch/shared/widgets/howmuch_section.dart';

class PriceAlertSubscriptionScreen extends ConsumerWidget {
  const PriceAlertSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(priceAlertSettingsProvider);

    return HowmuchScaffold(
      title: '5-B 가격 알림 구독',
      subtitle: '관심 지역과 카테고리를 고르면 가격 변동을 더 빨리 확인할 수 있습니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('관심 카테고리'),
          const SizedBox(height: 8),
          _ChipEditor(
            values: const ['한식', '분식', '카페', '중식', '미용', '세탁'],
            selected: settings.categories,
            onChanged: (values) =>
                ref.read(priceAlertSettingsProvider.notifier).state = settings
                    .copyWith(categories: values),
          ),
          const SizedBox(height: 20),
          const SectionTitle('관심 지역'),
          const SizedBox(height: 8),
          _ChipEditor(
            values: const ['마포구', '서대문구', '은평구', '종로구', '중구'],
            selected: settings.regions,
            onChanged: (values) =>
                ref.read(priceAlertSettingsProvider.notifier).state = settings
                    .copyWith(regions: values),
          ),
          const SizedBox(height: 20),
          HowmuchCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('찜한 매장만 알림'),
                  value: settings.onlyFavorites,
                  onChanged: (value) =>
                      ref.read(priceAlertSettingsProvider.notifier).state =
                          settings.copyWith(onlyFavorites: value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('가격 인하 알림'),
                  value: settings.notifyOnDrop,
                  onChanged: (value) =>
                      ref.read(priceAlertSettingsProvider.notifier).state =
                          settings.copyWith(notifyOnDrop: value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('가격 인상 알림'),
                  value: settings.notifyOnRise,
                  onChanged: (value) =>
                      ref.read(priceAlertSettingsProvider.notifier).state =
                          settings.copyWith(notifyOnRise: value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          HowmuchButton(
            label: '구독 설정 저장',
            icon: Icons.save,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('가격 알림 구독 설정을 저장했습니다.')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipEditor extends StatelessWidget {
  const _ChipEditor({
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final List<String> values;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final isSelected = selected.contains(value);

        return FilterChip(
          label: Text(value),
          selected: isSelected,
          onSelected: (checked) {
            final next = [...selected];
            if (checked) {
              next.add(value);
            } else {
              next.remove(value);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}
