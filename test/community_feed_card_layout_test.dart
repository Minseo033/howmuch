import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/community/presentation/screens/community_feed_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('photo and text-only cards align reactions to the same corner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: CommunityFeedScreen()));
      await tester.pumpAndSettle();

      final photoCard = tester.getRect(
        find.byKey(const ValueKey('feed-card-with-image')),
      );
      final photoReactions = tester.getRect(
        find.byKey(const ValueKey('feed-reactions-with-image')),
      );
      final textCard = tester.getRect(
        find.byKey(const ValueKey('feed-card-without-image')),
      );
      final textReactions = tester.getRect(
        find.byKey(const ValueKey('feed-reactions-without-image')),
      );

      final photoRightGap = photoCard.right - photoReactions.right;
      final textRightGap = textCard.right - textReactions.right;
      final photoBottomGap = photoCard.bottom - photoReactions.bottom;
      final textBottomGap = textCard.bottom - textReactions.bottom;

      expect(photoRightGap, closeTo(textRightGap, 0.1));
      expect(photoBottomGap, closeTo(textBottomGap, 0.1));
      expect(photoRightGap, inInclusiveRange(16, 18));
      expect(photoBottomGap, inInclusiveRange(16, 18));
      expect(tester.takeException(), isNull);
    }, () => MockClient(_feedResponse));
  });
}

Future<http.Response> _feedResponse(http.Request request) async {
  if (!request.url.path.endsWith('/api/community/feed')) {
    return http.Response('{}', 404);
  }

  final body = jsonEncode([
    {
      'id': 'with-image',
      'location': '구로구',
      'title': '노랑통닭 알싸한 마늘 치킨 24000',
      'storeName': '노랑통닭',
      'menu': '알싸한 마늘 치킨',
      'price': '24000',
      'author': '김민서',
      'likes': 2,
      'comments': 3,
      'status': 'APPROVED',
      'createdAt': '2026-09-01T09:00:00Z',
      'imageUrls': ['https://example.com/menu.jpg'],
    },
    {
      'id': 'without-image',
      'location': '구로구',
      'title': '동양미래대학교 학식당 한식 6500',
      'storeName': '동양미래대학교 학식당',
      'menu': '한식',
      'price': '6500',
      'author': '김민서',
      'likes': 0,
      'comments': 0,
      'status': 'APPROVED',
      'createdAt': '2026-09-01T09:00:00Z',
      'imageUrls': <String>[],
    },
  ]);
  return http.Response(
    body,
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
