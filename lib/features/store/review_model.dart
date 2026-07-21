/// 매장 리뷰 모델.
/// 백엔드 /api/review 응답 필드와 매칭됩니다.
class Review {
  final String id;
  final String storeId;
  final String storeName;
  final String authorName;
  final int stars;
  final String menu;
  final String content;
  final int likes;
  final String? ownerReply;
  final DateTime? createdAt;

  const Review({
    this.id = '',
    required this.storeId,
    this.storeName = '',
    required this.authorName,
    required this.stars,
    this.menu = '',
    required this.content,
    this.likes = 0,
    this.ownerReply,
    this.createdAt,
  });

  /// 아바타에 표시할 작성자 이니셜
  String get initial => authorName.isNotEmpty ? authorName[0] : '?';

  /// "n분 전 / n일 전" 형태의 상대 시간
  String get timeAgo {
    final created = createdAt;
    if (created == null) return '';
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7}주 전';
    return '${diff.inDays ~/ 30}개월 전';
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: (json['reviewId'] ?? json['id'] ?? '').toString(),
      storeId: (json['storeId'] ?? '').toString(),
      storeName: (json['storeName'] ?? '').toString(),
      authorName:
          (json['authorName'] ?? json['name'] ?? '익명').toString(),
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      menu: (json['menu'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      ownerReply: json['ownerReply']?.toString(),
      createdAt: _parseCreatedAt(json['createdAt']),
    );
  }

  static DateTime? _parseCreatedAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    if (raw is Map) {
      // Firestore Timestamp 직렬화 형태 대응
      final seconds = raw['_seconds'] ?? raw['seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
      }
      return null;
    }
    return DateTime.tryParse(raw.toString());
  }

  /// 리뷰 작성 요청용 페이로드 (백엔드 ReviewRequest와 매칭)
  Map<String, dynamic> toCreateJson() => {
        'storeId': storeId,
        'storeName': storeName,
        'authorName': authorName,
        'menu': menu,
        'content': content,
        'stars': stars,
      };
}