import 'package:flutter_riverpod/flutter_riverpod.dart';

class StoreReviewNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  StoreReviewNotifier() : super(_initialReviews);

  static final List<Map<String, dynamic>> _initialReviews = [
    {
      'initial': '절',
      'name': '절약왕민수',
      'stars': 4,
      'timeAgo': '2일 전',
      'menu': '김치찌개',
      'content': '5,500원에 이 양과 맛이면 진짜 가성비 최고예요. 반찬도 깔끔합니다.',
      'likes': 24,
      'ownerReply': '늘 감사합니다 :)',
    },
    {
      'initial': '동',
      'name': '동네탐험가',
      'stars': 5,
      'timeAgo': '5일 전',
      'menu': '제육볶음',
      'content': '양이 진짜 많아요. 1인분으로 둘이 먹어도 충분.',
      'likes': 18,
      'ownerReply': null,
    },
    {
      'initial': '강',
      'name': '강남직장인',
      'stars': 5,
      'timeAgo': '1주 전',
      'menu': '된장찌개',
      'content': '회사 점심으로 자주 가요. 가격 안 올라서 좋네요.',
      'likes': 11,
      'ownerReply': null,
    },
  ];

  // 새 리뷰 추가용 메서드 (차후 다나님 연동 대비)
  void addReview(Map<String, dynamic> review) {
    state = [review, ...state];
  }
}

final storeReviewProvider = StateNotifierProvider<StoreReviewNotifier, List<Map<String, dynamic>>>((ref) {
  return StoreReviewNotifier();
});
