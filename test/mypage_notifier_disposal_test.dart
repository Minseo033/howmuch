import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'notification settings load completion is ignored after dispose',
    () async {
      final api = _BlockingNotificationSettingsApi();
      final notifier = NotificationSettingsNotifier(api);
      await Future<void>.delayed(Duration.zero);

      notifier.dispose();
      api.complete(NotificationSettings.defaults);

      await Future<void>.delayed(Duration.zero);
    },
  );

  test('price alert load completion is ignored after dispose', () async {
    final api = _BlockingPriceAlertApi();
    final notifier = PriceAlertSettingsNotifier(api);
    await Future<void>.delayed(Duration.zero);

    notifier.dispose();
    api.complete(
      const PriceAlertSettings(
        all: false,
        stores: [],
        notifyOnDrop: true,
        notifyOnRise: true,
        notifyOnNewMenu: false,
      ),
    );

    await Future<void>.delayed(Duration.zero);
  });

  test('favorite load completion is ignored after dispose', () async {
    final api = _BlockingFavoriteApi();
    final profile = StateController<UserProfile>(UserProfile.guest);
    final notifier = FavoriteStoresNotifier(api, profile);

    final load = notifier.loadFavorites();
    await Future<void>.delayed(Duration.zero);
    notifier.dispose();
    api.complete(const []);

    await expectLater(load, completes);
    profile.dispose();
  });
}

class _BlockingNotificationSettingsApi extends NotificationSettingsApiService {
  _BlockingNotificationSettingsApi()
    : super(MockClient((_) async => http.Response('{}', 200)));

  final Completer<NotificationSettings> _completer = Completer();

  @override
  Future<NotificationSettings> fetchSettings() => _completer.future;

  void complete(NotificationSettings settings) => _completer.complete(settings);
}

class _BlockingPriceAlertApi extends PriceAlertApiService {
  _BlockingPriceAlertApi()
    : super(MockClient((_) async => http.Response('[]', 200)));

  final Completer<PriceAlertSettings> _completer = Completer();

  @override
  Future<PriceAlertSettings> fetchSettings() => _completer.future;

  void complete(PriceAlertSettings settings) => _completer.complete(settings);
}

class _BlockingFavoriteApi extends FavoriteApiService {
  final Completer<List<FavoriteStoreModel>> _completer = Completer();

  @override
  Future<List<FavoriteStoreModel>> fetchFavorites() => _completer.future;

  void complete(List<FavoriteStoreModel> favorites) {
    _completer.complete(favorites);
  }
}
