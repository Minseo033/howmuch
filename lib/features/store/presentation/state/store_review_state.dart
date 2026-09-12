import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';

/// 매장 리뷰 상태.
/// storeId → 리뷰 목록 맵으로 관리하며, 백엔드 /api/review와 연동합니다.
class StoreReviewNotifier
    extends StateNotifier<Map<String, AsyncValue<List<Review>>>> {
  StoreReviewNotifier() : super(const {});

  /// 이미 로드를 시도한 storeId (중복 요청 방지)
  final Set<String> _loadedStoreIds = {};
  final Set<String> _loadingStoreIds = {};

  List<Review> reviewsFor(String storeId) =>
      state[storeId]?.valueOrNull ?? const [];

  /// 특정 매장의 리뷰 목록을 서버에서 조회 (공개 API)
  Future<void> loadReviews(String storeId, {bool force = false}) async {
    if (!mounted ||
        storeId.isEmpty ||
        _loadingStoreIds.contains(storeId) ||
        (!force && _loadedStoreIds.contains(storeId))) {
      return;
    }
    _loadingStoreIds.add(storeId);
    final previousIds = reviewsFor(storeId).map((review) => review.id).toSet();
    final previous = state[storeId];
    state = {
      ...state,
      storeId: previous == null
          ? const AsyncValue.loading()
          : const AsyncLoading<List<Review>>().copyWithPrevious(previous),
    };

    final url = ApiClient.uri('/api/review', {'storeId': storeId});
    try {
      final response = await ApiClient.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(ApiClient.defaultTimeout);

      if (response.statusCode != 200) {
        throw Exception('리뷰 조회 실패: ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) throw const FormatException('리뷰 응답 형식 오류');

      final reviews = decoded
          .whereType<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList();
      if (!mounted) return;
      // Preserve reviews submitted while an older list request was pending.
      final added = reviewsFor(storeId).where(
        (review) =>
            !previousIds.contains(review.id) &&
            !reviews.any((loaded) => loaded.id == review.id),
      );
      _loadedStoreIds.add(storeId);
      state = {
        ...state,
        storeId: AsyncValue.data([...added, ...reviews]),
      };
    } catch (e, stackTrace) {
      debugPrint('리뷰 조회 통신 에러: $e');
      if (!mounted) return;
      _loadedStoreIds.remove(storeId);
      state = {
        ...state,
        storeId: AsyncError<List<Review>>(
          e,
          stackTrace,
        ).copyWithPrevious(state[storeId] ?? const AsyncValue.loading()),
      };
    } finally {
      _loadingStoreIds.remove(storeId);
    }
  }

  /// 리뷰 작성 (세션 인증 필요). 성공 시 로컬 목록 맨 앞에 추가하고 true 반환.
  Future<bool> addReview(Review review) async {
    if (!mounted) return false;
    final url = ApiClient.uri('/api/review');
    try {
      final response = await ApiClient.post(
        url,
        headers: ApiClient.jsonHeaders(auth: true),
        body: jsonEncode(review.toCreateJson()),
      ).timeout(ApiClient.defaultTimeout);

      if (response.statusCode == 401) {
        throw const MyReviewsAuthRequiredException();
      }

      if (response.statusCode != 200) {
        debugPrint(
          '리뷰 등록 실패: ${response.statusCode} ${ApiClient.bodyText(response)}',
        );
        return false;
      }

      final data = ApiClient.decodeJson(response) as Map<String, dynamic>;
      final saved = Review(
        id: (data['reviewId'] ?? '').toString(),
        storeId: review.storeId,
        storeName: review.storeName,
        authorName: review.authorName,
        stars: review.stars,
        menu: review.menu,
        price: review.price,
        content: review.content,
        createdAt: DateTime.now(),
      );
      if (!mounted) return true;
      final current = reviewsFor(review.storeId);
      state = {
        ...state,
        review.storeId: AsyncValue.data([saved, ...current]),
      };
      return true;
    } catch (e) {
      debugPrint('리뷰 등록 통신 에러: $e');
      return false;
    }
  }
}

final storeReviewProvider =
    StateNotifierProvider<
      StoreReviewNotifier,
      Map<String, AsyncValue<List<Review>>>
    >((ref) {
      return StoreReviewNotifier();
    });

/// 로그인한 사용자의 리뷰 목록 상태.
class MyReviewsNotifier extends StateNotifier<AsyncValue<List<Review>>> {
  MyReviewsNotifier() : super(const AsyncValue.loading());

  bool _loaded = false;
  int _generation = 0;

  /// 리뷰 작성 등 외부 변경 시 캐시 무효화 — 다음 화면 진입 시 재조회됩니다.
  void invalidate() {
    _loaded = false;
    _generation++;
  }

  Future<void> loadReviews({bool force = false}) async {
    if (!mounted || (_loaded && !force)) return;
    final generation = ++_generation;

    if (!ApiClient.isAuthenticated) {
      // _loaded를 true로 두면 로그인 후 재진입필 때 early return되어
      // 계속 '로그인이 필요해요'만 표시되므로, 미인증 상태는 로드 완료로 간주하지 않습니다.
      state = AsyncValue.error(
        const MyReviewsAuthRequiredException(),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();
    try {
      final response = await ApiClient.get(
        ApiClient.uri('/api/review/me'),
        headers: ApiClient.jsonHeaders(auth: true),
      ).timeout(ApiClient.defaultTimeout);

      if (response.statusCode != 200) {
        throw Exception('내 리뷰 조회 실패: ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        throw const FormatException('내 리뷰 응답 형식이 올바르지 않습니다.');
      }

      final reviews = decoded
          .whereType<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList();
      if (!mounted || generation != _generation) return;
      _loaded = true;
      state = AsyncValue.data(reviews);
    } catch (error, stackTrace) {
      debugPrint('내 리뷰 조회 통신 에러: $error');
      if (!mounted || generation != _generation) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final myReviewsProvider =
    StateNotifierProvider<MyReviewsNotifier, AsyncValue<List<Review>>>((ref) {
      ref.watch(
        authStateProvider.select(
          (auth) => (auth.isLoggedIn, auth.firebaseUid, auth.sessionToken),
        ),
      );
      return MyReviewsNotifier();
    });

class MyReviewsAuthRequiredException implements Exception {
  const MyReviewsAuthRequiredException();
}
