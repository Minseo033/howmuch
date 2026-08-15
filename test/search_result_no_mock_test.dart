import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/store/store_model.dart';

void main() {
  testWidgets('shows a retry state instead of fabricated stores', (tester) async {
    final previousStores = HomeMapScreen.globalAllStores;
    HomeMapScreen.globalAllStores = <Store>[];
    addTearDown(() => HomeMapScreen.globalAllStores = previousStores);

    await tester.pumpWidget(
      const MaterialApp(
        home: SearchResultScreen(initialQuery: '김치찌개'),
      ),
    );
    await tester.pump();

    expect(find.text('매장 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('김치찌개 맛집 1호'), findsNothing);
  });
}
