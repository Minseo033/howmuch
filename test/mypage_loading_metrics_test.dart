import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/mypage/presentation/screens/mypage_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'logged-in user does not flash misleading 0원/0곳 during initial profile summary loading',
    (tester) async {
      await ApiClient.setSessionToken('active-test-token');
      addTearDown(() => ApiClient.setSessionToken(null));

      final completer = Completer<void>();
      late WidgetRef savedRef;

      final router = GoRouter(
        initialLocation: '/mypage',
        routes: [
          GoRoute(
            path: '/mypage',
            builder: (_, _) => MypageScreen(
              profileSummaryLoader: (ref) {
                savedRef = ref;
                return completer.future;
              },
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => const AuthState(
                isLoggedIn: true,
                provider: 'kakao',
                email: 'tester@example.com',
                sessionToken: 'active-test-token',
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      // First frame: profile summary request is in-flight and not yet completed
      await tester.pump();

      // Must NOT flash misleading 0원 or 0곳 inside profile metrics
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mypage-metric-saved-amount')),
          matching: find.text('0원'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mypage-metric-report-count')),
          matching: find.text('0곳'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mypage-metric-favorite-count')),
          matching: find.text('0곳'),
        ),
        findsNothing,
      );

      // Metric labels are still rendered correctly
      expect(find.text('이번 달 절약'), findsOneWidget);
      expect(find.text('제보 매장'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mypage-metric-favorite-count')),
          matching: find.text('찜한 매장'),
        ),
        findsOneWidget,
      );

      // Complete the profile summary load with real data
      savedRef
          .read(userProfileProvider.notifier)
          .update(
            (state) => state.copyWith(
              savedAmount: 15000,
              reportCount: 2,
              favoriteStoreCount: 3,
            ),
          );
      completer.complete();
      await tester.pumpAndSettle();

      // Now real loaded values appear
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mypage-metric-saved-amount')),
          matching: find.text('15,000원'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mypage-metric-report-count')),
          matching: find.text('2곳'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mypage-metric-favorite-count')),
          matching: find.text('3곳'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('guest user displays guest numbers without indefinite skeleton', (
    tester,
  ) async {
    await ApiClient.setSessionToken(null);

    final router = GoRouter(
      initialLocation: '/mypage',
      routes: [
        GoRoute(path: '/mypage', builder: (_, _) => const MypageScreen()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => const AuthState(
              isLoggedIn: false,
              provider: 'guest',
              email: '',
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mypage-metric-saved-amount')),
        matching: find.text('0원'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mypage-metric-report-count')),
        matching: find.text('0곳'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mypage-metric-favorite-count')),
        matching: find.text('0곳'),
      ),
      findsOneWidget,
    );
  });
}
