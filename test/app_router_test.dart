import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/app_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('direct web route cold start still begins at splash validation', () {
    binding.platformDispatcher.defaultRouteNameTestValue = AppRoutes.mypage;
    addTearDown(binding.platformDispatcher.clearDefaultRouteNameTestValue);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.splash);
  });
}
