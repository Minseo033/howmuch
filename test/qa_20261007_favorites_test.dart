import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/screens/favorite_stores_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFavoriteApi extends FavoriteApiService {
  final removed = <String>[];

  @override
  Future<List<FavoriteStoreModel>> fetchFavorites() async => [
    FavoriteStoreModel.fromJson({
      'storeId': 'store-1',
      'storeName': '무한칼국수 송담점',
      'industry': '한식',
      'menu1': '칼국수',
      'price1': '7000',
    }),
  ];

  @override
  Future<void> removeFavorite(String storeId) async => removed.add(storeId);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('favorites-session');
  });

  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets('the unfavorite dialog keeps the list visible and its buttons '
      'say keep or remove (QA #38)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeFavoriteApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [favoriteApiServiceProvider.overrideWithValue(api)],
        child: const MaterialApp(home: FavoriteStoresScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('찜 해제'));
    await tester.pumpAndSettle();
    expect(find.text('찜을 해제할까요?'), findsOneWidget);
    // 대화상자 뒤에 찜 목록(검색칸과 매장 카드)이 그대로 있습니다.
    expect(find.text('찜한 매장 검색'), findsOneWidget);
    expect(find.text('무한칼국수 송담점'), findsNWidgets(2));
    expect(find.text('취소'), findsNothing);
    expect(find.text('찜 취소'), findsNothing);

    await tester.tap(find.text('유지하기'));
    await tester.pumpAndSettle();
    expect(find.text('찜을 해제할까요?'), findsNothing);
    expect(api.removed, isEmpty);
    expect(find.text('무한칼국수 송담점'), findsOneWidget);

    await tester.tap(find.text('찜 해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '찜 해제'));
    await tester.pumpAndSettle();
    expect(api.removed, ['store-1']);
    expect(find.text('찜을 해제할까요?'), findsNothing);
    expect(find.text('무한칼국수 송담점 찜을 해제했어요.'), findsOneWidget);
  });
}
