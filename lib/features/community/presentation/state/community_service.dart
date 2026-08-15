import 'dart:convert';

import 'package:howmuch/core/network/api_client.dart';
import 'package:http/http.dart' as http;

class CommunityApiException implements Exception {
  const CommunityApiException(this.statusCode, [this.message]);

  final int statusCode;
  final String? message;

  @override
  String toString() => 'CommunityApiException($statusCode, $message)';
}

class CommunityReactionResult {
  const CommunityReactionResult({required this.count, required this.enabled});

  final int count;
  final bool enabled;

  factory CommunityReactionResult.fromJson(
    Map<String, dynamic> json, {
    required int fallbackCount,
    required bool fallbackEnabled,
  }) {
    return CommunityReactionResult(
      count:
          _readInt(json, const ['likes', 'likeCount', 'count']) ??
          fallbackCount,
      enabled:
          _readBool(json, const ['likedByMe', 'liked', 'enabled']) ??
          fallbackEnabled,
    );
  }
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
    required this.isMine,
    required this.replyCount,
    required this.replies,
  });

  final String id;
  final String author;
  final String content;
  final String createdAt;
  final bool isMine;
  final int replyCount;
  final List<CommunityComment> replies;

  String get initial => author.isNotEmpty ? author[0] : '익';

  CommunityComment copyWith({
    int? replyCount,
    List<CommunityComment>? replies,
  }) {
    return CommunityComment(
      id: id,
      author: author,
      content: content,
      createdAt: createdAt,
      isMine: isMine,
      replyCount: replyCount ?? this.replyCount,
      replies: replies ?? this.replies,
    );
  }

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    final repliesRaw = _readList(json, const ['replies', 'children']);
    final replies = repliesRaw
        .whereType<Map>()
        .map(
          (reply) =>
              CommunityComment.fromJson(Map<String, dynamic>.from(reply)),
        )
        .toList();

    return CommunityComment(
      id:
          _readString(json, const ['id', 'commentId', 'replyId']) ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      author:
          _readString(json, const [
            'author',
            'authorName',
            'authorNickname',
            'nickname',
            'writer',
          ]) ??
          '알 수 없음',
      content:
          _readString(json, const ['content', 'body', 'text', 'message']) ?? '',
      createdAt:
          _readString(json, const ['createdAt', 'createdDate', 'date']) ?? '',
      isMine: _readBool(json, const ['isMine', 'mine', 'ownedByMe']) ?? false,
      replyCount:
          _readInt(json, const ['replyCount', 'repliesCount']) ??
          replies.length,
      replies: replies,
    );
  }
}

class CommunityService {
  const CommunityService();

  Future<Map<String, dynamic>> fetchFeedDetail(String postId) async {
    final response = await http
        .get(
          ApiClient.uri('/api/community/feed/${Uri.encodeComponent(postId)}'),
          headers: ApiClient.jsonHeaders(auth: true),
        )
        .timeout(ApiClient.defaultTimeout);

    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        ApiClient.bodyText(response),
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<List<CommunityComment>> fetchComments(String postId) async {
    final response = await http
        .get(
          ApiClient.uri(
            '/api/community/feed/${Uri.encodeComponent(postId)}/comments',
          ),
          headers: ApiClient.jsonHeaders(auth: true),
        )
        .timeout(ApiClient.defaultTimeout);

    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        ApiClient.bodyText(response),
      );
    }

    return _decodeCommentList(response.bodyBytes);
  }

  Future<CommunityComment?> createComment(String postId, String content) async {
    final response = await http
        .post(
          ApiClient.uri(
            '/api/community/feed/${Uri.encodeComponent(postId)}/comments',
          ),
          headers: ApiClient.jsonHeaders(auth: true),
          body: jsonEncode({'content': content}),
        )
        .timeout(ApiClient.defaultTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw CommunityApiException(
        response.statusCode,
        ApiClient.bodyText(response),
      );
    }
    if (response.bodyBytes.isEmpty) return null;

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) return null;
    return CommunityComment.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<List<CommunityComment>> fetchReplies(String commentId) async {
    final response = await http
        .get(
          ApiClient.uri(
            '/api/community/comments/${Uri.encodeComponent(commentId)}/replies',
          ),
          headers: ApiClient.jsonHeaders(auth: true),
        )
        .timeout(ApiClient.defaultTimeout);

    if (response.statusCode != 200) {
      throw CommunityApiException(
        response.statusCode,
        ApiClient.bodyText(response),
      );
    }

    return _decodeCommentList(response.bodyBytes);
  }

  Future<CommunityComment?> createReply(
    String commentId,
    String content,
  ) async {
    final response = await http
        .post(
          ApiClient.uri(
            '/api/community/comments/${Uri.encodeComponent(commentId)}/replies',
          ),
          headers: ApiClient.jsonHeaders(auth: true),
          body: jsonEncode({'content': content}),
        )
        .timeout(ApiClient.defaultTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw CommunityApiException(
        response.statusCode,
        ApiClient.bodyText(response),
      );
    }
    if (response.bodyBytes.isEmpty) return null;

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) return null;
    return CommunityComment.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<CommunityReactionResult> setLike({
    required String postId,
    required bool liked,
    required int currentCount,
  }) async {
    final uri = ApiClient.uri(
      '/api/community/feed/${Uri.encodeComponent(postId)}/like',
    );
    final response = liked
        ? await http
              .post(uri, headers: ApiClient.jsonHeaders(auth: true))
              .timeout(ApiClient.defaultTimeout)
        : await http
              .delete(uri, headers: ApiClient.jsonHeaders(auth: true))
              .timeout(ApiClient.defaultTimeout);

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw CommunityApiException(
        response.statusCode,
        ApiClient.bodyText(response),
      );
    }
    if (response.bodyBytes.isEmpty) {
      return CommunityReactionResult(
        count: liked
            ? currentCount + 1
            : (currentCount - 1).clamp(0, currentCount),
        enabled: liked,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map) {
      return CommunityReactionResult.fromJson(
        Map<String, dynamic>.from(decoded),
        fallbackCount: currentCount,
        fallbackEnabled: liked,
      );
    }
    return CommunityReactionResult(count: currentCount, enabled: liked);
  }

  Future<bool> setNotification({
    required String postId,
    required bool enabled,
  }) async {
    final uri = ApiClient.uri(
      '/api/community/feed/${Uri.encodeComponent(postId)}/notification',
    );
    final response = enabled
        ? await http
              .post(uri, headers: ApiClient.jsonHeaders(auth: true))
              .timeout(ApiClient.defaultTimeout)
        : await http
              .delete(uri, headers: ApiClient.jsonHeaders(auth: true))
              .timeout(ApiClient.defaultTimeout);

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw CommunityApiException(
        response.statusCode,
        ApiClient.bodyText(response),
      );
    }
    if (response.bodyBytes.isEmpty) return enabled;

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map) {
      return _readBool(Map<String, dynamic>.from(decoded), const [
            'notificationEnabled',
            'enabled',
            'subscribed',
          ]) ??
          enabled;
    }
    return enabled;
  }

  List<CommunityComment> _decodeCommentList(List<int> bodyBytes) {
    final decoded = jsonDecode(utf8.decode(bodyBytes));
    final rawList = decoded is List
        ? decoded
        : decoded is Map
        ? _readList(Map<String, dynamic>.from(decoded), const [
            'comments',
            'replies',
            'data',
            'items',
          ])
        : const [];

    return rawList
        .whereType<Map>()
        .map(
          (comment) =>
              CommunityComment.fromJson(Map<String, dynamic>.from(comment)),
        )
        .where((comment) => comment.content.isNotEmpty)
        .toList();
  }
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString();
    if (text.isNotEmpty) return text;
  }
  return null;
}

int? _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
  }
  return null;
}

bool? _readBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
  }
  return null;
}

List<dynamic> _readList(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is List) return value;
  }
  return const [];
}
