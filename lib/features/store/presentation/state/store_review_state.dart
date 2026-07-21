import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/review_model.dart';

/// 매장 리뷰 상태.
/// storeId → 리뷰 목록 맵으로 관리하며, 백엔드 /api/review와 연동합니다.
class StoreReviewNotifier extends StateNotifier<Map<String, List<Review>>> {
  StoreReviewNotifier() : super(const {});

  /// 이미 로드를 시도한 storeId (중복 요청 방지)
  final Set<String> _loadedStoreIds = {};

  List<Review> reviewsFor(String storeId) => state[storeId] ?? const [];

  /// 특정 매장의 리뷰 목록을 서버에서 조회 (공개 API)
  Future<void> loadReviews(String storeId) async {
    if (storeId.isEmpty || _loadedStoreIds.contains(storeId)) return;
    _loadedStoreIds.add(storeId);

    final url = ApiClient.uri('/api/review', {'storeId': storeId});
    try {
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode != 200) {
        debugPrint('리뷰 조회 실패: ${response.statusCode}');
        return;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) return;

      final reviews = decoded
          .whereType<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList();
      state = {...state, storeId: reviews};
    } catch (e) {
      debugPrint('리뷰 조회 통신 에러: $e');
    }
  }

  /// 리뷰 작성 (세션 인증 필요). 성공 시 로컬 목록 맨 앞에 추가하고 true 반환.
  Future<bool> addReview(Review review) async {
    final url = ApiClient.uri('/api/review');
    try {
      final response = await http
          .post(
            url,
            headers: ApiClient.jsonHeaders(auth: true),
            body: jsonEncode(review.toCreateJson()),
          )
          .timeout(ApiClient.defaultTimeout);

      if (response.statusCode != 200) {
        debugPrint('리뷰 등록 실패: ${response.statusCode} ${response.body}');
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final saved = Review(
        id: (data['reviewId'] ?? '').toString(),
        storeId: review.storeId,
        storeName: review.storeName,
        authorName: review.authorName,
        stars: review.stars,
        menu: review.menu,
        content: review.content,
        createdAt: DateTime.now(),
      );
      final current = state[review.storeId] ?? const <Review>[];
      state = {
        ...state,
        review.storeId: [saved, ...current],
      };
      return true;
    } catch (e) {
      debugPrint('리뷰 등록 통신 에러: $e');
      return false;
    }
  }
}

final storeReviewProvider =
    StateNotifierProvider<StoreReviewNotifier, Map<String, List<Review>>>(
        (ref) {
  return StoreReviewNotifier();
});