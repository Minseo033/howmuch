import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/search/presentation/state/search_filter_policy.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QA 2026-10-07 #31 and #33: the search screen.
void main() {
  // The names sort the other way round from the distances.
  final far = _store('far', '가 창원 칼국수', '5,000', 35.2280, 128.6811);
  final middle = _store('middle', '나 청주 칼국수', '5,000', 36.6424, 127.4890);
  final near = _store('near', '다 시청 칼국수', '5,000', 37.5663, 126.9779);
  final cheaper = _store('cheaper', '라 부산 칼국수', '4,000', 35.1796, 129.0756);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HomeMapScreen.setSearchCatalog([far, middle, near, cheaper]);
    HomeMapScreen.globalUserPosition = _position(37.5665, 126.9780);
  });

  tearDown(() {
    HomeMapScreen.setSearchCatalog(const []);
    HomeMapScreen.globalUserPosition = null;
  });

  test('the same price is ordered by distance when it is known (#31)', () {
    final distances = {'far': 300.0, 'middle': 110.0, 'near': 0.1};
    final sorted = [far, middle, near, cheaper]
      ..sort(
        (a, b) => SearchFilterPolicy.compareByPrice(
          a,
          b,
          distanceOf: (store) => distances[store.id] ?? 900,
        ),
      );
    expect(sorted.map((store) => store.id), [
      'cheaper',
      'near',
      'middle',
      'far',
    ]);
    // Without a position the order by name is kept.
    final byName = [near, far, middle]..sort(SearchFilterPolicy.compareByPrice);
    expect(byName.map((store) => store.id), ['far', 'middle', 'near']);
  });

  testWidgets('cheapest-first lists nearer stores first at the same price '
      '(#31)', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: SearchResultScreen(
          initialQuery: '칼국수',
          initialFilter: SearchFilter(sortOrder: '저렴한순'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tops = [
      for (final name in ['라 부산 칼국수', '다 시청 칼국수', '나 청주 칼국수', '가 창원 칼국수'])
        tester.getTopLeft(find.text(name)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('tapping outside the search box closes the keyboard (#33)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SearchResultScreen(initialQuery: '칼국수')),
    );
    await tester.pumpAndSettle();

    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();
    bool hasFocus() => tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;
    expect(hasFocus(), isTrue);

    // The result count line, as in the QA report.
    await tester.tap(find.textContaining('검색 결과', findRichText: true));
    await tester.pump();
    expect(hasFocus(), isFalse);
    expect(find.text('다 시청 칼국수'), findsOneWidget, reason: 'still on search');
  });
}

Store _store(
  String id,
  String name,
  String price,
  double latitude,
  double longitude,
) => Store.fromJson({
  'storeId': id,
  'storeName': name,
  'industry': '한식',
  'menu1': '칼국수',
  'price1': price,
  'latitude': latitude,
  'longitude': longitude,
  'source': 'GOV',
});

Position _position(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.now(),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
