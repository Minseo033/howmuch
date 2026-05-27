import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/features/home/presentation/state/home_mock_data.dart';
import 'package:howmuch/features/home/presentation/widgets/home_map_canvas.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';

class HomeMapScreen extends StatelessWidget {
  const HomeMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HowmuchScaffold(
      title: '2-1 홈 / 메인 지도',
      subtitle: '네이버지도 또는 카카오지도 API 연동 전까지 교체 가능한 지도 캔버스로 구성합니다.',
      actions: [
        IconButton(
          tooltip: '마이페이지',
          icon: const Icon(Icons.person),
          onPressed: () => context.go(AppRoutes.mypage),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        tooltip: '현재 위치',
        onPressed: () {},
        child: const Icon(Icons.my_location),
      ),
      child: Column(
        children: [
          TextField(
            readOnly: true,
            onTap: () => context.go(AppRoutes.emptySearchResult),
            decoration: const InputDecoration(
              hintText: '매장명, 메뉴, 지역을 검색해보세요',
              prefixIcon: Icon(Icons.search),
              suffixIcon: Icon(Icons.tune),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _CategoryChip(label: '전체', selected: true),
                _CategoryChip(label: '한식'),
                _CategoryChip(label: '분식'),
                _CategoryChip(label: '카페'),
                _CategoryChip(label: '1km 이내'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const HomeMapCanvas(stores: nearbyStores),
          const SizedBox(height: 14),
          for (final store in nearbyStores) ...[
            _NearbyStoreTile(store: store),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.networkError),
            icon: const Icon(Icons.wifi_off),
            label: const Text('네트워크 오류 상태 보기'),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {},
      ),
    );
  }
}

class _NearbyStoreTile extends StatelessWidget {
  const _NearbyStoreTile({required this.store});

  final NearbyStore store;

  @override
  Widget build(BuildContext context) {
    return HowmuchCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.storefront,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text('${store.category} · ${store.distance} · ${store.price}'),
              ],
            ),
          ),
          Chip(label: Text(store.badge)),
        ],
      ),
    );
  }
}
