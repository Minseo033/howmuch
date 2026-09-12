import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';

FavoriteStoreModel favorite(String id) =>
    FavoriteStoreModel.fromJson({'storeId': id, 'storeName': id});

class PendingFavoriteApi extends FavoriteApiService {
  List<FavoriteStoreModel> initial = [];
  final additions = <String, Completer<FavoriteStoreModel>>{};
  final removals = <String, Completer<void>>{};
  @override
  Future<List<FavoriteStoreModel>> fetchFavorites() async => initial;
  @override
  Future<FavoriteStoreModel> addFavorite({
    required String storeId,
    required String storeName,
  }) {
    return (additions[storeId] = Completer<FavoriteStoreModel>()).future;
  }

  @override
  Future<void> removeFavorite(String storeId) =>
      (removals[storeId] = Completer<void>()).future;
}

void main() {
  late PendingFavoriteApi api;
  late FavoriteStoresNotifier notifier;
  late StateController<UserProfile> profile;
  setUp(() {
    api = PendingFavoriteApi();
    profile = StateController(UserProfile.guest);
    notifier = FavoriteStoresNotifier(api, profile);
  });
  tearDown(() {
    notifier.dispose();
    profile.dispose();
  });

  test(
    'independent additions survive responses arriving in reverse order',
    () async {
      await notifier.loadFavorites();
      final a = notifier.addFavorite(storeId: 'A', storeName: 'A');
      final b = notifier.addFavorite(storeId: 'B', storeName: 'B');
      api.additions['B']!.complete(favorite('B'));
      await b;
      api.additions['A']!.complete(favorite('A'));
      await a;
      expect(notifier.state.requireValue.map((s) => s.id), ['B', 'A']);
      expect(profile.state.favoriteStoreCount, 2);
    },
  );

  test(
    'one failed removal does not restore another successfully removed store',
    () async {
      api.initial = [favorite('A'), favorite('B')];
      await notifier.loadFavorites();
      final a = notifier.removeFavorite('A');
      final failure = expectLater(a, throwsStateError);
      final b = notifier.removeFavorite('B');
      api.removals['B']!.complete();
      await b;
      api.removals['A']!.completeError(StateError('offline'));
      await failure;
      expect(notifier.state.requireValue.map((s) => s.id), ['A']);
      expect(profile.state.favoriteStoreCount, 1);
    },
  );
}
