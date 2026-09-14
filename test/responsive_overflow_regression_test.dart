import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/price_alert_subscription_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/privacy_policy_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/terms_of_service_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/search/presentation/screens/search_result_screen.dart';
import 'package:howmuch/features/store/presentation/screens/directions_external_app_screen.dart';
import 'package:howmuch/features/store/presentation/screens/price_change_report_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _MockPriceAlertApiService extends PriceAlertApiService {
  _MockPriceAlertApiService() : super(http.Client());

  @override
  Future<PriceAlertSettings> fetchSettings() async {
    return const PriceAlertSettings(
      all: true,
      stores: [
        PriceAlertStore(
          storeId: 'store-1',
          storeName: '착한식당',
          menuName: '비빔밥 5,000원',
          enabled: true,
        ),
      ],
      notifyOnRise: true,
      notifyOnDrop: true,
      notifyOnNewMenu: true,
    );
  }

  @override
  Future<PriceAlertSettings> saveSettings(PriceAlertSettings settings) async =>
      settings;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testStore = Store(
    id: 's-overflow-test',
    storeName: '역삼 착한 곰탕 식당 본점',
    address: '서울특별시 강남구 테헤란로 123길 45',
    phoneNumber: '02-123-4567',
    industry: '한식',
    menu1: '곰탕',
    price1: '6000',
    menu2: '특 곰탕',
    price2: '8000',
    menu3: '수육',
    price3: '15000',
    menu4: '',
    price4: '',
    latitude: 37.50,
    longitude: 127.03,
    source: 'GOV',
  );

  group('320x568 and 568x320 Responsive Overflow Regression Tests', () {
    const viewports = <String, Size>{
      '320x568 (narrow mobile)': Size(320, 568),
      '568x320 (landscape)': Size(568, 320),
    };

    for (final entry in viewports.entries) {
      final label = entry.key;
      final size = entry.value;

      testWidgets('PrivacyPolicyScreen renders without overflow on $label', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: PrivacyPolicyScreen())),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('TermsOfServiceScreen renders without overflow on $label', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: TermsOfServiceScreen())),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'DirectionsExternalAppScreen renders without overflow on $label',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            const MaterialApp(
              home: DirectionsExternalAppScreen(
                storeName: '착한식당',
                address: '서울시 중구 세종대로 110',
                distanceLabel: '250m',
                latitude: 37.5670,
                longitude: 126.9780,
                startLatitude: 37.5665,
                startLongitude: 126.9780,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'PriceAlertSubscriptionScreen renders without overflow on $label',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final mockApi = _MockPriceAlertApiService();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) =>
                    const PriceAlertSubscriptionScreen(),
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                priceAlertApiServiceProvider.overrideWithValue(mockApi),
                priceAlertSettingsProvider.overrideWith(
                  (ref) => PriceAlertSettingsNotifier(mockApi),
                ),
              ],
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('SearchResultScreen renders without overflow on $label', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final previous = HomeMapScreen.globalAllStores;
        HomeMapScreen.globalAllStores = [testStore];
        addTearDown(() => HomeMapScreen.globalAllStores = previous);

        await tester.pumpWidget(
          const MaterialApp(home: SearchResultScreen(initialQuery: '곰탕')),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'PriceChangeReportScreen renders without overflow on $label',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: PriceChangeReportScreen(
                  store: testStore,
                  storeName: testStore.storeName,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
