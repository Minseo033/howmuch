import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/community/presentation/state/community_service.dart';

void main() {
  group('CommunityComment', () {
    test('parses the backend comment contract', () {
      final comment = CommunityComment.fromJson({
        'id': 'comment-1',
        'author': '민서',
        'content': '좋은 정보예요',
        'createdAt': '2026-08-11T10:00:00Z',
        'isMine': true,
        'replyCount': 2,
      });

      expect(comment.id, 'comment-1');
      expect(comment.author, '민서');
      expect(comment.content, '좋은 정보예요');
      expect(comment.isMine, isTrue);
      expect(comment.replyCount, 2);
      expect(comment.replies, isEmpty);
    });

    test('parses nested replies and compatibility aliases', () {
      final comment = CommunityComment.fromJson({
        'commentId': 'comment-2',
        'nickname': '태관',
        'body': '댓글',
        'mine': false,
        'children': [
          {
            'replyId': 'reply-1',
            'writer': '다나',
            'text': '답글',
            'ownedByMe': true,
          },
        ],
      });

      expect(comment.id, 'comment-2');
      expect(comment.replyCount, 1);
      expect(comment.replies.single.id, 'reply-1');
      expect(comment.replies.single.isMine, isTrue);
    });
  });

  test('CommunityReactionResult parses like state and count', () {
    final result = CommunityReactionResult.fromJson(
      {'likes': 7, 'likedByMe': true},
      fallbackCount: 0,
      fallbackEnabled: false,
    );

    expect(result.count, 7);
    expect(result.enabled, isTrue);
  });
}
