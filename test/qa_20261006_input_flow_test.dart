import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/app_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/community/presentation/screens/community_post_detail_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_create_screen.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/errors/presentation/screens/store_info_report_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/store/presentation/screens/price_history_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('qa-test-session');
  });
  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets('actual history CTA passes slot through application router', (
    tester,
  ) async {
    final store = Store.fromJson({
      'storeId': 'test',
      'storeName': '식당',
      'menu1': '같은 메뉴',
      'price1': '3000',
      'menu3': '같은 메뉴',
      'price3': '5000',
      'menu4': '네 번째',
      'price4': '7000',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    router.go(
      AppRoutes.priceHistory,
      extra: PriceHistoryTarget(store: store, menuIndex: 3),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('가격 변동 제보하기'));
    await tester.pumpAndSettle();
    expect(find.text('기존 가격 5,000원'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '같은 메뉴',
    );
  });

  testWidgets('five-row imported draft cannot upload or submit', (
    tester,
  ) async {
    var requests = 0;
    final initial = UserReportStatus(
      id: 'draft',
      store: '식당',
      menu: '',
      status: '검토 중',
      statusColor: 0,
      statusBg: 0,
      textColor: 0,
      category: '한식',
      address: '서울',
      menuPrices: [
        for (var i = 1; i <= 5; i++)
          UserReportMenuPrice(menu: '메뉴$i', price: '5000'),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (_) =>
                const AuthState(isLoggedIn: true, provider: '카카오', email: ''),
          ),
          reportServiceProvider.overrideWithValue(
            ReportService(
              MockClient((_) async {
                requests++;
                return http.Response('{}', 200);
              }),
            ),
          ),
        ],
        child: MaterialApp(home: ReportCreateScreen(initialReport: initial)),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('제보 수정하기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('제보 수정하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('초과 메뉴를 제거해주세요'), findsOneWidget);
    expect(validateReportMenuCount(initial.menuPrices.length), isNotNull);
    expect(requests, 0);
  });

  testWidgets(
    'STORE_INFO edit PUT retains id, type, description and attachment',
    (tester) async {
      final data = <String, dynamic>{
        'id': 'info-1',
        'storeId': 'existing-store',
        'storeName': '매장',
        'status': 'PENDING',
        'reportType': 'STORE_INFO',
        'changeType': 'other',
        'description': '기존 설명',
        'menu1': '국수',
        'price1': '5000',
        'imageUrls': ['https://example.com/original.jpg'],
      };
      http.Request? saved;
      final service = ReportService(
        MockClient((request) async {
          if (request.method == 'PUT') {
            saved = request;
            return http.Response('{"success":true}', 200);
          }
          return http.Response(
            jsonEncode([data]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final container = ProviderContainer(
        overrides: [reportServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);
      router.go(AppRoutes.myReportsV2);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      router.push(
        AppRoutes.storeInfoReport,
        extra: StoreInfoReportTarget(
          initialReport: UserReportStatus.fromJson(data),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '수정 설명');
      await tester.tap(find.text('신고 접수하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(saved?.url.path, '/api/report/store/info-1');
      final body = jsonDecode(saved!.body) as Map;
      expect(body['reportType'], 'STORE_INFO');
      expect(body['changeType'], 'other');
      expect(body['description'], '수정 설명');
      expect(body['imageUrls'], data['imageUrls']);
    },
  );

  testWidgets(
    'composer remains directly above keyboard rather than adding inset twice',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CommunityPostDetailScreen()),
        ),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FilledButton)).bottom, closeTo(552, 2));
      expect(tester.getRect(find.byType(TextField)).bottom, greaterThan(520));
      expect(tester.takeException(), isNull);
    },
  );
}
