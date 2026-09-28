import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/community/presentation/screens/community_feed_screen.dart';

void main() {
  test('현재 위치의 구·동 표기 차이를 허용한다', () {
    const keys = ['서울특별시 구로구 고척제1동', '구로구', '고척제1동'];

    expect(communityLocationMatches('구로구', keys), isTrue);
    expect(communityLocationMatches('고척제1동', keys), isTrue);
    expect(communityLocationMatches('서울 구로구', keys), isTrue);
    expect(communityLocationMatches('강남구', keys), isFalse);
    expect(communityLocationMatches('알 수 없음', keys), isFalse);
  });

  testWidgets('지역 칩에서 전체와 현재 위치를 선택할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CommunityFeedScreen()));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const ValueKey('community-location-filter')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('전체 제보'), findsOneWidget);
    expect(find.text('현재 위치'), findsOneWidget);
    final pickerRect = tester.getRect(
      find.byKey(const ValueKey('community-location-picker')),
    );
    expect(pickerRect.top, greaterThanOrEqualTo(0));
    expect(pickerRect.bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('전체 제보'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('전체 제보'), findsNothing);
    expect(find.text('전체'), findsOneWidget);
  });

  testWidgets('320px 피드에서 지역·분류 칩의 탭 영역이 44px 이상이다', (tester) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CommunityFeedScreen()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      tester
          .getSize(find.byKey(const ValueKey('community-location-filter')))
          .height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('community-filter-chip-최신 제보')))
          .height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });
}
