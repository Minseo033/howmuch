import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/app/app_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/app/app_route_observer.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/home/presentation/screens/home_map_screen.dart';
import 'package:howmuch/features/community/presentation/screens/community_feed_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/mypage_screen.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_report_dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken(null);
  });

  testWidgets(
    'main tabs are lazy, retain State and still identify pushed pages',
    (tester) async {
      final container = ProviderContainer();
      final router = container.read(appRouterProvider);
      addTearDown(container.dispose);
      addTearDown(router.dispose);
      var requests = 0;
      await http.runWithClient(
        () async {
          router.go(AppRoutes.mypage);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.pumpAndSettle();
          final myState = tester.state(find.byType(MypageScreen));
          expect(find.byType(HomeMapScreen, skipOffstage: false), findsNothing);
          expect(
            find.byType(SavingsReportDashboardScreen, skipOffstage: false),
            findsNothing,
          );
          final changes = container
              .read(appNavigationTrackerProvider)
              .pageChanges;

          router.go(AppRoutes.savingsReportDashboard);
          await tester.pumpAndSettle();
          final reportState = tester.state(
            find.byType(SavingsReportDashboardScreen),
          );
          expect(
            container.read(appNavigationTrackerProvider).pageChanges,
            greaterThan(changes),
          );
          expect(
            TickerMode.valuesOf(
              tester.element(find.byType(MypageScreen, skipOffstage: false)),
            ).enabled,
            isFalse,
          );

          router.go(AppRoutes.mypage);
          await tester.pumpAndSettle();
          expect(tester.state(find.byType(MypageScreen)), same(myState));
          expect(
            tester.state(
              find.byType(SavingsReportDashboardScreen, skipOffstage: false),
            ),
            same(reportState),
          );
          expect(find.byType(HomeMapScreen, skipOffstage: false), findsNothing);

          router.push<void>(AppRoutes.privacyPolicy);
          await tester.pumpAndSettle();
          expect(visibleAppPath(router), AppRoutes.privacyPolicy);
          router.pop();
          await tester.pumpAndSettle();
          expect(visibleAppPath(router), AppRoutes.mypage);
          expect(tester.state(find.byType(MypageScreen)), same(myState));
          expect(
            requests,
            0,
            reason: 'unvisited home and guest summaries do no network work',
          );
          router.go(AppRoutes.communityFeed);
          await tester.pumpAndSettle();
          final feedState = tester.state(find.byType(CommunityFeedScreen));
          expect(requests, 1);
          router.go(AppRoutes.mypage);
          await tester.pumpAndSettle();
          router.go(AppRoutes.communityFeed);
          await tester.pumpAndSettle();
          expect(
            tester.state(find.byType(CommunityFeedScreen)),
            same(feedState),
          );
          expect(
            requests,
            1,
            reason: 'a fresh retained feed makes no duplicate request',
          );
          ApiClient.invalidateReadCache(paths: {'/api/report/my'});
          router.go(AppRoutes.mypage);
          await tester.pumpAndSettle();
          router.go(AppRoutes.communityFeed);
          await tester.pumpAndSettle();
          expect(
            requests,
            2,
            reason: 'a report change refreshes the retained feed',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((_) async {
          requests++;
          return http.Response('[]', 200);
        }),
      );
    },
  );
}
