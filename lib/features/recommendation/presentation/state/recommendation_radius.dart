import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';

const defaultRecommendationRadiusMeters = 3000;

bool validRecommendationRadius(int value) =>
    value >= 1000 && value <= 15000 && value % 1000 == 0;

final recommendationRadiusProvider =
    StateNotifierProvider<RecommendationRadiusNotifier, int>((ref) {
      final uid = ref.watch(
        authStateProvider.select((auth) => auth.firebaseUid),
      );
      return RecommendationRadiusNotifier(uid);
    });

/// This preference is device-local and isolated by account. Loading cannot
/// overwrite a radius the user has already changed in the current session.
class RecommendationRadiusNotifier extends StateNotifier<int> {
  RecommendationRadiusNotifier(this.accountId)
    : super(defaultRecommendationRadiusMeters) {
    ready = _load().catchError((Object _) {
      /* Storage unavailable: retain safe default. */
    });
  }

  final String accountId;
  late final Future<void> ready;
  bool _changed = false;
  int get radiusMeters => state;
  String get preferenceKey => 'recommendation_radius_v1_$accountId';

  Future<void> _load() async {
    if (accountId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(preferenceKey);
    if (mounted &&
        !_changed &&
        saved != null &&
        validRecommendationRadius(saved)) {
      state = saved;
    }
  }

  Future<bool> setRadius(int meters) async {
    if (!validRecommendationRadius(meters)) {
      throw ArgumentError.value(meters, 'meters', '1~15km, 1km 단위');
    }
    _changed = true;
    state = meters;
    if (accountId.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(preferenceKey, meters);
    } catch (_) {
      return false;
    }
  }
}
