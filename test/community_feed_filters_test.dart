import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/community/presentation/screens/community_feed_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

final _feed = [
  {
    'id': 'rise-1',
    'location': '구로구',
    'cityProvince': '서울',
    'title': '가격 오른 식당 국수 6000',
    'storeName': '가격 오른 식당',
    'menu': '국수',
    'price': '6000',
    'author': '민서',
    'likes': 1,
    'comments': 0,
    'status': 'PENDING',
    'changeType': 'rise',
    'createdAt': '2026-10-05T09:00:00Z',
    'imageUrls': <String>[],
  },
  {
    'id': 'new-store',
    'location': '구로구',
    'cityProvince': '서울',
    'title': '새로 생긴 식당 백반 7000',
    'storeName': '새로 생긴 식당',
    'menu': '백반',
    'price': '7000',
    'author': '태관',
    'likes': 0,
    'comments': 0,
    'status': 'APPROVED',
    'changeType': null,
    'createdAt': '2026-10-04T09:00:00Z',
    'imageUrls': <String>[],
  },
];

void _useMobileView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('current location filter (FE-COMM-5)', () {
    bool matches(
      String location,
      String province,
      ({String province, String district}) region,
    ) => communityLocationMatches(
      location,
      const [],
      itemProvince: province,
      selectedProvince: region.province,
      selectedDistrict: region.district,
    );

    test('requires the same province and district', () {
      final gangseo = communityRegionFromAddress('서울특별시 강서구 화곡1동');
      expect(gangseo.province, '서울');
      expect(gangseo.district, '강서구');
      expect(matches('강서구', '서울', gangseo), isTrue);
      expect(matches('서구', '인천', gangseo), isFalse);
      expect(matches('강서구', '부산', gangseo), isFalse);

      final seoulJung = communityRegionFromAddress('서울특별시 중구 명동');
      expect(matches('중구', '부산', seoulJung), isFalse);
      expect(matches('중구', '서울특별시', seoulJung), isTrue);

      final bundang = communityRegionFromAddress('경기도 성남시 분당구 삼평동');
      expect(bundang.province, '경기');
      expect(bundang.district, '성남시 분당구');
      expect(matches('성남시 분당구', '경기', bundang), isTrue);
      expect(matches('성남시 수정구', '경기', bundang), isFalse);
      expect(
        matches(
          '익산시',
          '전북특별자치도',
          communityRegionFromAddress('전북특별자치도 익산시 부송동'),
        ),
        isTrue,
      );
    });

    test('keeps the old partial match when the feed has no province', () {
      const keys = ['서울특별시 구로구 고척제1동', '구로구', '고척제1동'];
      expect(communityLocationMatches('구로구', keys), isTrue);
      expect(
        communityLocationMatches(
          '구로구',
          keys,
          itemProvince: '',
          selectedProvince: '서울',
          selectedDistrict: '구로구',
        ),
        isTrue,
      );
    });
  });

  testWidgets('price change filter and badge use changeType (FE-COMM-4)', (
    tester,
  ) async {
    _useMobileView(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: CommunityFeedScreen()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('feed-price-change-rise-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('feed-price-change-new-store')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('community-filter-chip-가격 변동')),
      );
      await tester.pumpAndSettle();
      expect(find.text('가격 오른 식당'), findsOneWidget);
      expect(find.text('새로 생긴 식당'), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) async => _json(_feed)));
  });

  testWidgets('a failed pull to refresh keeps the list (FE-COMM-16)', (
    tester,
  ) async {
    _useMobileView(tester);
    var fail = false;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: CommunityFeedScreen()));
        await tester.pumpAndSettle();
        expect(find.text('가격 오른 식당'), findsOneWidget);

        fail = true;
        await tester.fling(
          find.byType(ListView).last,
          const Offset(0, 400),
          1200,
        );
        await tester.pumpAndSettle();

        expect(find.text('가격 오른 식당'), findsOneWidget);
        expect(find.text('피드를 불러오지 못했어요'), findsNothing);
        expect(find.text('피드를 새로 불러오지 못했어요. 잠시 후 다시 시도해주세요.'), findsOneWidget);
      },
      () => MockClient(
        (_) async => fail ? _json({'message': '오류'}, 500) : _json(_feed),
      ),
    );
  });

  testWidgets('an empty feed can be refreshed (FE-COMM-21)', (tester) async {
    _useMobileView(tester);
    var calls = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: CommunityFeedScreen()));
        await tester.pumpAndSettle();
        expect(find.text('아직 제보가 없어요. 첫 제보를 남겨보세요!'), findsOneWidget);

        await tester.tap(find.text('새로고침'));
        await tester.pumpAndSettle();
        expect(find.text('가격 오른 식당'), findsOneWidget);
      },
      () => MockClient((_) async {
        calls++;
        return _json(calls == 1 ? <Object>[] : _feed);
      }),
    );
  });
}
