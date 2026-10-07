import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/community/presentation/screens/community_post_detail_screen.dart';
import 'package:howmuch/features/community/presentation/state/community_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: _jsonHeaders);

Map<String, dynamic> _post() => {
  'id': 'p1',
  'title': '동네 식당 국수 5000',
  'storeName': '동네 식당',
  'menu1': '국수',
  'price1': '5000',
  'author': '민서',
  'location': '구로구',
  'status': 'APPROVED',
  'likes': 0,
  'comments': 3,
  'visitedRecently': true,
  'checkedMenuPrice': true,
  'createdAt': '2026-10-01T00:00:00Z',
};

Future<void> _pumpDetail(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: CommunityPostDetailScreen(postId: 'p1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('comment-test-session');
  });

  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets(
    'replying to a collapsed comment keeps its earlier replies (P1-8)',
    (tester) async {
      final replies = <Map<String, dynamic>>[
        {'id': 'r1', 'author': '다나', 'content': '첫 번째 답글'},
        {'id': 'r2', 'author': '태관', 'content': '두 번째 답글'},
      ];
      await http.runWithClient(
        () async {
          await _pumpDetail(tester);
          expect(find.text('답글 2개 보기'), findsOneWidget);
          // 자가 체크 항목은 인증처럼 보이지 않게 제보자 기준으로 표시합니다.
          expect(find.text('제보자 최근 방문'), findsOneWidget);
          expect(find.text('최근 방문 인증'), findsNothing);

          await tester.tap(find.text('답글'));
          await tester.pump();
          await tester.enterText(find.byType(TextField), '세 번째 답글');
          // The send button turns on once the typed text is shown.
          await tester.pump();
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();

          expect(find.text('첫 번째 답글'), findsOneWidget);
          expect(find.text('두 번째 답글'), findsOneWidget);
          expect(find.text('세 번째 답글'), findsOneWidget);
          expect(find.text('답글 접기'), findsOneWidget);
        },
        () => MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/community/feed/p1') return _json(_post());
          if (path == '/api/community/feed/p1/comments') {
            return _json([
              {
                'id': 'c1',
                'author': '민서',
                'content': '원 댓글',
                'replyCount': replies.length,
              },
            ]);
          }
          if (path == '/api/community/comments/c1/replies') {
            if (request.method == 'POST') {
              final created = {
                'id': 'r3',
                'author': '나',
                'content': '세 번째 답글',
                'isMine': true,
              };
              replies.add(created);
              return _json(created);
            }
            return _json(replies);
          }
          return _json({}, 404);
        }),
      );
    },
  );

  testWidgets('expanding re-fetches replies when the loaded count is stale', (
    tester,
  ) async {
    var replyFetches = 0;
    await http.runWithClient(
      () async {
        await _pumpDetail(tester);
        await tester.tap(find.text('답글 2개 보기'));
        await tester.pumpAndSettle();
        expect(find.text('먼저 단 답글'), findsOneWidget);
        expect(find.text('나중에 달린 답글'), findsOneWidget);
        expect(replyFetches, 1);
      },
      () => MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/community/feed/p1') return _json(_post());
        if (path == '/api/community/feed/p1/comments') {
          // 서버가 답글 하나만 함께 보내도 답글 수는 2개입니다.
          return _json([
            {
              'id': 'c1',
              'author': '민서',
              'content': '원 댓글',
              'replyCount': 2,
              'replies': [
                {'id': 'r1', 'author': '다나', 'content': '먼저 단 답글'},
              ],
            },
          ]);
        }
        if (path == '/api/community/comments/c1/replies') {
          replyFetches++;
          return _json([
            {'id': 'r1', 'author': '다나', 'content': '먼저 단 답글'},
            {'id': 'r2', 'author': '태관', 'content': '나중에 달린 답글'},
          ]);
        }
        return _json({}, 404);
      }),
    );
  });

  testWidgets(
    'a failed comment refresh keeps the visible comments (FE-COMM-15)',
    (tester) async {
      var failCommentList = false;
      await http.runWithClient(
        () async {
          await _pumpDetail(tester);
          await tester.enterText(find.byType(TextField), '새 댓글');
          await tester.pump();
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();

          expect(find.text('원 댓글'), findsOneWidget);
          expect(find.text('새 댓글'), findsOneWidget);
          // Sent: the composer is empty again.
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
          );
          expect(find.text('댓글을 불러오지 못했어요.'), findsNothing);
        },
        () => MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/community/feed/p1') return _json(_post());
          if (path == '/api/community/feed/p1/comments') {
            if (request.method == 'POST') {
              failCommentList = true;
              return _json({'id': 'c2', 'author': '나', 'content': '새 댓글'});
            }
            if (failCommentList) return _json({'message': '오류'}, 500);
            return _json([
              {'id': 'c1', 'author': '민서', 'content': '원 댓글'},
            ]);
          }
          return _json({}, 404);
        }),
      );
    },
  );

  testWidgets(
    'pull to refresh survives detail and comment failures (FE-COMM-24)',
    (tester) async {
      var failEverything = false;
      await http.runWithClient(
        () async {
          await _pumpDetail(tester);
          failEverything = true;
          await tester.fling(find.byType(ListView), const Offset(0, 400), 1200);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('원 댓글'), findsOneWidget);
        },
        () => MockClient((request) async {
          if (failEverything) return _json({'message': '오류'}, 500);
          final path = request.url.path;
          if (path == '/api/community/feed/p1') return _json(_post());
          if (path == '/api/community/feed/p1/comments') {
            return _json([
              {'id': 'c1', 'author': '민서', 'content': '원 댓글'},
            ]);
          }
          return _json({}, 404);
        }),
      );
    },
  );

  testWidgets(
    'shows the server reason when a comment is rejected (FE-COMM-23)',
    (tester) async {
      await http.runWithClient(
        () async {
          await _pumpDetail(tester);
          final field = tester.widget<TextField>(find.byType(TextField));
          expect(
            field.inputFormatters!.single,
            isA<LengthLimitingTextInputFormatter>().having(
              (formatter) => formatter.maxLength,
              'maxLength',
              communityCommentMaxLength,
            ),
          );
          await tester.enterText(find.byType(TextField), '금지된 단어');
          await tester.pump();
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(find.text('부적절한 표현이 포함되어 있어요.'), findsOneWidget);
        },
        () => MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/community/feed/p1') return _json(_post());
          if (path == '/api/community/feed/p1/comments') {
            if (request.method == 'POST') {
              return _json({
                'success': false,
                'message': '부적절한 표현이 포함되어 있어요.',
              }, 400);
            }
            return _json(<Object>[]);
          }
          return _json({}, 404);
        }),
      );
    },
  );

  testWidgets('a deleted post is shown as not found (FE-COMM-28)', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await _pumpDetail(tester);
        expect(find.text('게시글을 찾을 수 없어요'), findsOneWidget);
        expect(find.text('목록으로'), findsOneWidget);
        expect(find.text('네트워크 상태를 확인하고 다시 시도해주세요'), findsNothing);
      },
      () => MockClient((_) async => _json({'message': '게시글을 찾을 수 없습니다.'}, 404)),
    );
  });

  testWidgets('price change posts carry the price change badge (FE-COMM-4)', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await _pumpDetail(tester);
        expect(find.text('가격 변동'), findsOneWidget);
        expect(find.text('검토 중'), findsOneWidget);
      },
      () => MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/community/feed/p1') {
          return _json({..._post(), 'status': 'PENDING', 'changeType': 'rise'});
        }
        if (path == '/api/community/feed/p1/comments') {
          return _json(<Object>[]);
        }
        return _json({}, 404);
      }),
    );
  });

  testWidgets(
    'guests get a login prompt instead of a bare snackbar (FE-COMM-27)',
    (tester) async {
      await ApiClient.setSessionToken(null);
      await http.runWithClient(
        () async {
          await _pumpDetail(tester);
          await tester.tap(find.text('도움이 돼요 0'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('login_required_dialog')),
            findsOneWidget,
          );
        },
        () => MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/community/feed/p1') return _json(_post());
          if (path == '/api/community/feed/p1/comments') {
            return _json(<Object>[]);
          }
          return _json({}, 404);
        }),
      );
    },
  );

  test('emoji nicknames produce a whole avatar character', () {
    final comment = CommunityComment.fromJson({
      'id': 'c1',
      'author': '😀민서',
      'content': '좋아요',
    });
    expect(comment.initial, '😀');
    expect(
      const CommunityComment(
        id: 'c2',
        author: ' ',
        content: 'x',
        createdAt: '',
        isMine: false,
        replyCount: 0,
        replies: [],
      ).initial,
      '익',
    );
  });

  testWidgets('an empty comment cannot be sent and the button is named '
      '(QA 2026-10-07 #39)', (tester) async {
    final semantics = tester.ensureSemantics();
    await http.runWithClient(
      () async {
        await _pumpDetail(tester);
        FilledButton sendButton() =>
            tester.widget<FilledButton>(find.byType(FilledButton));

        expect(sendButton().onPressed, isNull);
        expect(find.bySemanticsLabel('댓글 등록'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '   ');
        await tester.pump();
        expect(sendButton().onPressed, isNull, reason: 'spaces only');

        await tester.enterText(find.byType(TextField), '가격 그대로예요');
        await tester.pump();
        expect(sendButton().onPressed, isNotNull);

        await tester.tap(find.text('답글'));
        await tester.pump();
        expect(find.bySemanticsLabel('답글 등록'), findsOneWidget);
      },
      () => MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/community/feed/p1') return _json(_post());
        if (path == '/api/community/feed/p1/comments') {
          return _json([
            {'id': 'c1', 'author': '민서', 'content': '원 댓글'},
          ]);
        }
        return _json({}, 404);
      }),
    );
    semantics.dispose();
  });

  testWidgets('a comment under a minute old still reads 방금 전 '
      '(QA 2026-10-07 #40)', (tester) async {
    String secondsAgo(int seconds) => DateTime.now()
        .toUtc()
        .subtract(Duration(seconds: seconds))
        .toIso8601String();
    await http.runWithClient(
      () async {
        await _pumpDetail(tester);
        expect(find.text('방금 전'), findsOneWidget);
        expect(find.text('0분 전'), findsNothing);
        expect(find.text('2분 전'), findsOneWidget);
      },
      () => MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/community/feed/p1') return _json(_post());
        if (path == '/api/community/feed/p1/comments') {
          return _json([
            {
              'id': 'c1',
              'author': '민서',
              'content': '방금 단 댓글',
              'createdAt': secondsAgo(50),
            },
            {
              'id': 'c2',
              'author': '다나',
              'content': '조금 전 댓글',
              'createdAt': secondsAgo(130),
            },
          ]);
        }
        return _json({}, 404);
      }),
    );
  });
}
