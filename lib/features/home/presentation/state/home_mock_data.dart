class NearbyStore {
  const NearbyStore({
    required this.name,
    required this.category,
    required this.distance,
    required this.price,
    required this.badge,
  });

  final String name;
  final String category;
  final String distance;
  final String price;
  final String badge;
}

const nearbyStores = [
  NearbyStore(
    name: '연남 국수',
    category: '한식',
    distance: '320m',
    price: '잔치국수 4,500원',
    badge: '공공데이터',
  ),
  NearbyStore(
    name: '성산동 김밥집',
    category: '분식',
    distance: '510m',
    price: '라면 3,500원',
    badge: '사용자 제보',
  ),
  NearbyStore(
    name: '망원 백반',
    category: '한식',
    distance: '780m',
    price: '오늘 백반 6,000원',
    badge: '착한가격',
  ),
];
