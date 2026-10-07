import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/errors/presentation/screens/store_info_report_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/inquiry_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_goal_setting_screen.dart';
import 'package:howmuch/features/store/presentation/screens/price_change_report_screen.dart';
import 'package:howmuch/features/store/presentation/screens/review_write_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QA 2026-10-07 #27, #35, #36, #37: store forms and form notices.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('qa-20261007-forms');
  });
  tearDown(() => ApiClient.setSessionToken(null));

  group('leaving a store form with input asks first (#35)', () {
    testWidgets('price change report', (tester) async {
      await _pumpForm(tester, PriceChangeReportScreen(store: _store()));
      await _expectClosesWithoutAsking(tester);

      await _openForm(tester);
      // 변경된 가격 칸.
      await tester.enterText(find.byType(TextField).at(1), '4500');
      await tester.pump();
      await _expectAsksBeforeLeaving(tester, title: '작성 중인 제보를 나갈까요?');
      expect(find.text('4500'), findsOneWidget, reason: 'the draft is kept');
      await _leaveAfterAsking(tester, title: '작성 중인 제보를 나갈까요?');
    });

    testWidgets('store info report', (tester) async {
      await _pumpForm(tester, StoreInfoReportScreen(store: _store()));
      await _expectClosesWithoutAsking(tester);

      await _openForm(tester);
      await tester.enterText(find.byType(TextField).last, '가격이 바뀌었어요');
      await tester.pump();
      await _expectAsksBeforeLeaving(tester, title: '작성 중인 신고를 나갈까요?');
      expect(find.text('가격이 바뀌었어요'), findsOneWidget);
      await _leaveAfterAsking(tester, title: '작성 중인 신고를 나갈까요?');
    });

    testWidgets('review', (tester) async {
      await _pumpForm(tester, ReviewWriteScreen(store: _store()));
      await _expectClosesWithoutAsking(tester);

      await _openForm(tester);
      // 별점만 골라도 작성 중인 리뷰입니다.
      await tester.tap(find.byIcon(Icons.star_rounded).at(3));
      await tester.pump();
      await _expectAsksBeforeLeaving(tester, title: '작성 중인 리뷰를 나갈까요?');
      expect(find.text('4.0'), findsOneWidget);
      await _leaveAfterAsking(tester, title: '작성 중인 리뷰를 나갈까요?');
    });

    testWidgets('editing a report asks only after something changed', (
      tester,
    ) async {
      final initial = UserReportStatus.fromJson({
        'id': 'info-1',
        'storeId': 'store-forms',
        'storeName': '동네 식당',
        'status': 'PENDING',
        'reportType': 'STORE_INFO',
        'changeType': 'other',
        'description': '기존 설명',
      });
      await _pumpForm(tester, StoreInfoReportScreen(initialReport: initial));
      // The restored report is not a change.
      await _expectClosesWithoutAsking(tester);

      await _openForm(tester);
      await tester.enterText(find.byType(TextField).last, '설명을 고쳤어요');
      await tester.pump();
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      expect(find.text('수정 중인 신고를 나갈까요?'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      expect(find.text('이전 화면'), findsOneWidget);
    });
  });

  testWidgets(
    'info report errors go away as soon as the field is fixed (#36)',
    (tester) async {
      await _pumpForm(tester, StoreInfoReportScreen(store: _store()));

      // '가격이 달라요'(기본 유형): 가격 오류는 가격을 입력하면 사라집니다.
      await tester.tap(find.text('신고 접수하기'));
      await tester.pump();
      const priceError = '실제 가격은 0보다 큰 정확한 금액을 입력해주세요.';
      expect(find.text(priceError), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '7000');
      await tester.pump();
      expect(find.text(priceError), findsNothing);

      // '기타': 내용 오류는 다음 제출을 기다리지 않고 입력하자마자 사라집니다.
      await tester.tap(find.text('기타'));
      await tester.pump();
      await tester.tap(find.text('신고 접수하기'));
      await tester.pump();
      expect(find.text('신고 내용을 입력해주세요.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '영업시간이 바뀌었어요');
      await tester.pump();
      expect(find.text('신고 내용을 입력해주세요.'), findsNothing);
    },
  );

  group('a new form notice replaces the one on screen (#37)', () {
    testWidgets('inquiry: the send button stays reachable under a notice', (
      tester,
    ) async {
      await _pumpInquiry(tester);

      await tester.tap(find.text('문의 보내기'));
      await tester.pumpAndSettle();
      expect(find.text('제목을 입력해주세요.'), findsOneWidget);
      expect(
        _snackBarRect(tester).bottom,
        lessThanOrEqualTo(
          tester
              .getRect(find.byKey(const ValueKey('inquiry-submit-button')))
              .top,
        ),
        reason: 'the notice must not cover the send button',
      );

      await tester.enterText(find.byType(TextField).at(0), '지도 오류');
      // A real tap: it has to reach the button while the notice shows.
      await tester.tap(find.text('문의 보내기'));
      await tester.pumpAndSettle();
      expect(find.text('내용을 입력해주세요.'), findsOneWidget);
      expect(find.text('제목을 입력해주세요.'), findsNothing);
    });

    testWidgets('savings goal: the next notice shows at once', (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: SavingsGoalSettingScreen()),
          );
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(TextField), '');
          await tester.tap(find.text('목표 저장하기'));
          await tester.pumpAndSettle();
          expect(find.text('목표 금액을 입력해주세요.'), findsOneWidget);
          expect(
            _snackBarRect(tester).bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(FilledButton)).top),
          );

          await tester.enterText(find.byType(TextField), '1000000001');
          await tester.tap(find.text('목표 저장하기'));
          await tester.pumpAndSettle();
          expect(find.text('절약 목표는 10억원 이하로 입력해주세요.'), findsOneWidget);
          expect(find.text('목표 금액을 입력해주세요.'), findsNothing);
        },
        () => MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.endsWith('/goal')
                  ? {'goalAmount': 20000}
                  : {'totalSavedAmount': 0, 'totalVisits': 0},
            ),
            200,
          ),
        ),
      );
    });

    testWidgets('price change report: the submit button stays reachable', (
      tester,
    ) async {
      await _pumpForm(tester, PriceChangeReportScreen(store: _store()));

      await tester.tap(find.text('가격 변동 제보하기'));
      await tester.pumpAndSettle();
      expect(find.text('변경된 가격을 입력해주세요.'), findsOneWidget);
      expect(
        _snackBarRect(tester).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('가격 변동 제보하기')).top),
      );

      await tester.enterText(find.byType(TextField).at(1), '4500');
      await tester.tap(find.text('가격 변동 제보하기'));
      await tester.pumpAndSettle();
      expect(find.text('메뉴판 가격을 직접 확인했다는 항목을 체크해주세요.'), findsOneWidget);
      expect(find.text('변경된 가격을 입력해주세요.'), findsNothing);
    });
  });

  testWidgets('review price hint uses the usual won format (#27)', (
    tester,
  ) async {
    await _pumpForm(tester, ReviewWriteScreen(store: _store(price1: '6500')));
    expect(find.text('6,500원 참고'), findsOneWidget);
    expect(find.text('6500 참고'), findsNothing);
  });
}

Store _store({String price1 = '4000'}) => Store.fromJson({
  'storeId': 'store-forms',
  'storeName': '동네 식당',
  'address': '서울 구로구 경인로 445',
  'menu1': '라면',
  'price1': price1,
  'menu2': '김밥',
  'price2': '3000',
  'latitude': 37.5,
  'longitude': 126.86,
});

Future<void> _pumpForm(WidgetTester tester, Widget form) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('이전 화면')),
      ),
      GoRoute(path: '/form', builder: (_, _) => form),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await _openForm(tester);
}

Future<void> _openForm(WidgetTester tester) async {
  final context = tester.element(find.byType(Navigator).first);
  GoRouter.of(context).push('/form');
  await tester.pumpAndSettle();
}

Future<void> _expectClosesWithoutAsking(WidgetTester tester) async {
  await tester.tap(find.byTooltip('뒤로가기'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsNothing);
  expect(find.text('이전 화면'), findsOneWidget);
}

Future<void> _expectAsksBeforeLeaving(
  WidgetTester tester, {
  required String title,
}) async {
  await tester.tap(find.byTooltip('뒤로가기'));
  await tester.pumpAndSettle();
  expect(find.text(title), findsOneWidget);
  await tester.tap(find.text('계속 작성'));
  await tester.pumpAndSettle();
  expect(find.text(title), findsNothing);
  expect(find.text('이전 화면'), findsNothing);
}

Future<void> _leaveAfterAsking(
  WidgetTester tester, {
  required String title,
}) async {
  // The system back gesture asks as well.
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(find.text(title), findsOneWidget);
  await tester.tap(find.text('나가기'));
  await tester.pumpAndSettle();
  expect(find.text('이전 화면'), findsOneWidget);
}

Rect _snackBarRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey('howmuch-snack-bar-surface')));

class _NoInquiryService extends InquiryService {
  @override
  Future<Map<String, dynamic>> createInquiry({
    required String title,
    required String content,
    String? category,
    List<String> imageUrls = const [],
  }) async => throw StateError('validation should stop the request');
}

Future<void> _pumpInquiry(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: AppRoutes.mypage,
    routes: [
      GoRoute(
        path: AppRoutes.mypage,
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push(AppRoutes.inquiry),
            child: const Text('마이페이지'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.inquiry,
        builder: (_, _) => const InquiryScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        inquiryServiceProvider.overrideWithValue(_NoInquiryService()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.tap(find.text('마이페이지'));
  await tester.pumpAndSettle();
}
