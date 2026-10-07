import 'dart:async';
import 'dart:convert';
import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/community/presentation/screens/community_feed_screen.dart';
import 'package:howmuch/features/community/presentation/screens/community_post_detail_screen.dart';
import 'package:howmuch/features/community/presentation/screens/my_reports/my_reports_v2_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_create_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_detail_v2_screen.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:howmuch/features/mypage/presentation/screens/account_management_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/connected_social_accounts_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/favorite_stores_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/inquiry_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/my_inquiries_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/mypage_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/notification_settings_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/price_alert_subscription_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/privacy_policy_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/profile_edit_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/public_data_source_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/terms_of_service_screen.dart';
import 'package:howmuch/features/mypage/presentation/screens/visit_history_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';
import 'package:howmuch/features/mypage/presentation/state/mypage_state.dart';
import 'package:howmuch/features/savings/presentation/screens/savings_goal_setting_screen.dart';
import 'package:howmuch/features/store/presentation/screens/price_change_report_screen.dart';
import 'package:howmuch/features/store/presentation/screens/review_write_screen.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/review_model.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/features/system/presentation/screens/report_delete_confirm_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// QA 10/7 #50, #53, #54, #55: names, roles and states screen readers get on
// the MY, community and form screens.

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

/// Nodes a screen reader announces as [name] (its label or tooltip).
SemanticsFinder _named(String name) => find.semantics.byPredicate((node) {
  if (node.isMergedIntoParent) return false;
  final data = node.getSemanticsData();
  return data.label == name || data.tooltip == name;
}, describeMatch: (_) => 'announced as "$name"');

/// The one node announced as [name].
SemanticsNode _single(String name) {
  final nodes = _named(name).evaluate().toList();
  expect(nodes, hasLength(1), reason: '"$name" should be a single node');
  return nodes.single;
}

/// The one button announced as [name], when plain text shares the name.
SemanticsNode _singleButton(String name) {
  final nodes = _named(name)
      .evaluate()
      .where((node) => node.getSemanticsData().flagsCollection.isButton)
      .toList();
  expect(nodes, hasLength(1), reason: 'one "$name" button');
  return nodes.single;
}

/// The text field announced as [name].
SemanticsNode _field(String name) {
  final nodes = find.semantics
      .byPredicate((node) {
        if (node.isMergedIntoParent) return false;
        final data = node.getSemanticsData();
        // An empty field also reads its hint after the name.
        return data.flagsCollection.isTextField &&
            data.label.split('\n').first == name;
      })
      .evaluate()
      .toList();
  expect(nodes, hasLength(1), reason: 'one text field named "$name"');
  return nodes.single;
}

/// Every node whose label contains [text].
Iterable<SemanticsNode> _containing(String text) =>
    find.semantics.byPredicate((node) {
      if (node.isMergedIntoParent) return false;
      return node.getSemanticsData().label.contains(text);
    }).evaluate();

final Matcher _button = isSemantics(isButton: true, hasTapAction: true);

void _phone(WidgetTester tester, {double height = 844}) {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _rejected = {
  'id': 'price-rejected',
  'storeId': 'store-jang',
  'storeName': '정장군숯불구이전문점',
  'changeType': 'rise',
  'menu1': '삼겹살(200g)',
  'price1': '16000',
  'status': 'REJECTED',
  'rejectReason': '메뉴판 사진으로 가격을 확인할 수 없어요.',
  'createdAt': '2026-09-23T03:00:00Z',
};
const _approved = {
  'id': 'legacy-approved',
  'storeName': '노랑통닭',
  'menu1': '후라이드',
  'price1': '17000',
  'status': 'APPROVED',
  'createdAt': '2026-09-01T03:00:00Z',
};

ReportService _reportService() => ReportService(
  MockClient((request) async {
    if (request.url.path == '/api/report/my') {
      return _json([_rejected, _approved]);
    }
    return http.Response('', 404);
  }),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('qa-1007-a11y');
  });

  tearDown(() => ApiClient.setSessionToken(null));

  group('reject reason dialog (#55)', () {
    testWidgets('title, reason and 확인 are separate nodes and 확인 closes it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      _phone(tester, height: 900);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reportServiceProvider.overrideWithValue(_reportService()),
          ],
          child: MaterialApp(
            home: ReportDetailV2Screen(
              initialReport: UserReportStatus.fromJson(_rejected),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = _single('반려 사유를 확인해주세요');
      expect(title, isSemantics(isButton: false));
      _single('메뉴판 사진으로 가격을 확인할 수 없어요.');
      expect(_single('확인'), _button);

      tester.semantics.tap(_named('확인'));
      await tester.pumpAndSettle();
      expect(find.text('반려 사유를 확인해주세요'), findsNothing);

      // The detail screen's delete action is a button too (#54).
      expect(_single('삭제하기'), _button);
      semantics.dispose();
    });
  });

  testWidgets('the delete dialog actions are buttons (#54)', (tester) async {
    final semantics = tester.ensureSemantics();
    _phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReportDeleteConfirmScreen(
            report: UserReportStatus.fromJson(_rejected),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['취소', '삭제하기']) {
      expect(
        _single(label),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
        reason: label,
      );
    }
    semantics.dispose();
  });

  testWidgets('my report filters say which one is on and how many (#54)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    _phone(tester, height: 1000);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reportServiceProvider.overrideWithValue(_reportService())],
        child: const MaterialApp(home: MyReportsV2Screen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _single('전체 2건'),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    expect(_single('반려 1건'), isSemantics(isButton: true, isSelected: false));
    expect(_single('새 제보 등록하기'), _button);

    tester.semantics.tap(_named('반려 1건'));
    await tester.pumpAndSettle();
    expect(_single('반려 1건'), isSemantics(isSelected: true));
    expect(_single('전체 2건'), isSemantics(isSelected: false));
    // A report card opens its detail.
    expect(
      _containing(
        '정장군숯불구이전문점',
      ).where((node) => node.getSemanticsData().flagsCollection.isButton),
      isNotEmpty,
    );
    semantics.dispose();
  });

  group('community (#50, #54)', () {
    final feed = [
      {
        'id': 'rise-1',
        'location': '구로구',
        'cityProvince': '서울',
        'title': '가격 오른 식당 국수 6000',
        'storeName': '가격 오른 식당',
        'menu': '국수',
        'price': '6000',
        'author': '민서',
        'likes': 1,
        'comments': 1,
        'status': 'APPROVED',
        'changeType': 'rise',
        'createdAt': '2026-10-05T09:00:00Z',
        'imageUrls': <String>[],
      },
    ];

    testWidgets('feed chips, cards and the report button are buttons and the '
        'counts say what they count', (tester) async {
      final semantics = tester.ensureSemantics();
      _phone(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: CommunityFeedScreen()));
        await tester.pumpAndSettle();

        expect(
          _single('최신 제보'),
          isSemantics(
            isButton: true,
            hasTapAction: true,
            isSelected: true,
            isInMutuallyExclusiveGroup: true,
          ),
        );
        expect(_single('가격 변동'), isSemantics(isSelected: false));
        tester.semantics.tap(_named('가격 변동'));
        await tester.pumpAndSettle();
        expect(_single('가격 변동'), isSemantics(isSelected: true));
        expect(_single('최신 제보'), isSemantics(isSelected: false));

        final card = _containing('가격 오른 식당').single;
        expect(card, _button);
        final label = card.getSemanticsData().label;
        expect(label, contains('도움이 돼요 1개, 댓글 1개'));
        expect(label, isNot(contains('·')));

        expect(_single('제보하기'), _button);
      }, () => MockClient((_) async => _json(feed)));
      semantics.dispose();
    });

    testWidgets('post detail reactions, reply and close buttons are named', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      _phone(tester, height: 1200);
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const ProviderScope(
              child: MaterialApp(home: CommunityPostDetailScreen(postId: 'p1')),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            _single('도움이 돼요 2'),
            isSemantics(
              isButton: true,
              hasTapAction: true,
              isSelected: true,
              hasEnabledState: true,
              isEnabled: true,
            ),
          );
          expect(
            _single('새 댓글 알림'),
            isSemantics(isButton: true, hasTapAction: true, isSelected: false),
          );

          expect(_single('답글'), _button);
          tester.semantics.tap(_named('답글'));
          await tester.pumpAndSettle();
          expect(find.text('민서님에게 답글'), findsOneWidget);
          expect(_single('답글 취소'), _button);
          tester.semantics.tap(_named('답글 취소'));
          await tester.pumpAndSettle();
          expect(find.text('민서님에게 답글'), findsNothing);

          await tester.tap(find.byType(PageView));
          await tester.pumpAndSettle();
          expect(_single('사진 닫기'), _button);
          tester.semantics.tap(_named('사진 닫기'));
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.close_rounded), findsNothing);
        },
        () => MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/community/feed/p1') {
            return _json({
              'id': 'p1',
              'title': '동네 식당 국수 5000',
              'storeName': '동네 식당',
              'menu1': '국수',
              'price1': '5000',
              'author': '다나',
              'location': '구로구',
              'status': 'APPROVED',
              'likes': 2,
              'likedByMe': true,
              'comments': 1,
              'imageUrls': ['https://example.com/menu.jpg'],
              'createdAt': '2026-10-01T00:00:00Z',
            });
          }
          if (path == '/api/community/feed/p1/comments') {
            return _json([
              {'id': 'c1', 'author': '민서', 'content': '원 댓글'},
            ]);
          }
          return _json({}, 404);
        }),
      );
      semantics.dispose();
    });
  });

  group('forms (#53)', () {
    final store = Store(
      id: 'store-1',
      storeName: '테스트 식당',
      address: '서울시 테스트구',
      phoneNumber: '',
      industry: '한식',
      menu1: '기본 메뉴',
      price1: '9000',
      menu2: '',
      price2: '',
      menu3: '',
      price3: '',
      menu4: '',
      price4: '',
      latitude: 37.5,
      longitude: 127.0,
      source: 'GOV',
    );

    testWidgets('review confirmations read their text and checked state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      _phone(tester, height: 1400);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storeReviewProvider.overrideWith((ref) => _Reviews())],
          child: MaterialApp(home: ReviewWriteScreen(store: store)),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['최근 1개월 이내 방문했어요', '가격 정보를 직접 확인했어요']) {
        expect(
          _single(label),
          isSemantics(
            hasCheckedState: true,
            isChecked: false,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
          reason: label,
        );
      }
      expect(_unnamedCheckboxes(), isEmpty);

      tester.semantics.tap(_named('최근 1개월 이내 방문했어요'));
      await tester.pump();
      expect(_single('최근 1개월 이내 방문했어요'), isSemantics(isChecked: true));
      semantics.dispose();
    });

    testWidgets('the price change confirmation is named', (tester) async {
      final semantics = tester.ensureSemantics();
      _phone(tester, height: 2000);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: PriceChangeReportScreen(store: store)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _single('직접 메뉴판 가격을 확인했어요'),
        isSemantics(
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );
      expect(_unnamedCheckboxes(), isEmpty);
      tester.semantics.tap(_named('직접 메뉴판 가격을 확인했어요'));
      await tester.pump();
      expect(_single('직접 메뉴판 가격을 확인했어요'), isSemantics(isChecked: true));
      semantics.dispose();
    });

    testWidgets('new store form: confirmations, menu rows by order and the '
        'current category', (tester) async {
      final semantics = tester.ensureSemantics();
      _phone(tester, height: 2400);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ReportCreateScreen())),
      );
      await tester.pumpAndSettle();

      for (final label in ['최근 1개월 이내 방문했어요', '메뉴판 가격을 직접 확인했어요']) {
        expect(
          _single(label),
          isSemantics(
            hasCheckedState: true,
            isChecked: false,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
          reason: label,
        );
      }
      tester.semantics.tap(_named('최근 1개월 이내 방문했어요'));
      await tester.pump();
      expect(_single('최근 1개월 이내 방문했어요'), isSemantics(isChecked: true));

      await tester.tap(find.text('메뉴 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('메뉴 추가'));
      await tester.pumpAndSettle();
      _field('대표 메뉴, 필수 입력');
      _field('가격, 필수 입력');
      for (final name in ['메뉴 2', '메뉴 3']) {
        _field('$name, 필수 입력');
        _field('$name 가격, 필수 입력');
        expect(_containing('$name 무료 여부'), hasLength(1));
      }

      await tester.tap(find.byTooltip('업종 선택'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('음식점 · 중식'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('업종 선택'));
      await tester.pumpAndSettle();
      expect(
        _single('음식점 · 중식'),
        isSemantics(
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      expect(_single('음식점 · 한식'), isSemantics(isSelected: false));
      semantics.dispose();
    });

    testWidgets('the goal amount field is named while loading and after', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      _phone(tester);
      final goal = Completer<http.Response>();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: SavingsGoalSettingScreen()),
          );
          await tester.pump();
          expect(
            _field('이번 달 절약 목표 금액'),
            isSemantics(hasEnabledState: true, isEnabled: false),
          );
          // While the goal loads, the spinner says so and the save button is
          // read as disabled because it is.
          _single('절약 목표를 불러오는 중');
          expect(
            _single('목표 저장하기'),
            isSemantics(
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
            ),
          );

          goal.complete(_json({'goalAmount': 20000}));
          await tester.pumpAndSettle();
          final field = _field('이번 달 절약 목표 금액');
          expect(field, isSemantics(isEnabled: true));
          expect(field.getSemanticsData().value, '20000');
          expect(
            _single('목표 저장하기'),
            isSemantics(isButton: true, hasEnabledState: true, isEnabled: true),
          );
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/goal')) return goal.future;
          return _json({'totalSavedAmount': 0, 'totalVisits': 0});
        }),
      );
      semantics.dispose();
    });
  });

  group('MY sub screens (#50)', () {
    final screens = <String, Widget Function()>{
      '알림 설정': () => const NotificationSettingsScreen(),
      '가격 알림': () => const PriceAlertSubscriptionScreen(),
      '로그인 계정': () => const ConnectedSocialAccountsScreen(),
      '서비스 이용약관': () => const Scaffold(body: TermsOfServiceScreen()),
      '개인정보 처리방침': () => const Scaffold(body: PrivacyPolicyScreen()),
      '공공데이터 출처': () => const PublicDataSourceScreen(),
      '문의하기': () => const InquiryScreen(),
      '내 문의 내역': () => const MyInquiriesScreen(),
      '찜한 매장': () => const FavoriteStoresScreen(),
      '방문 기록': () => const VisitHistoryScreen(),
      '계정 관리': () => const AccountManagementScreen(),
      '프로필 수정': () => const ProfileEditScreen(),
    };
    for (final MapEntry(key: name, value: build) in screens.entries) {
      testWidgets('$name: the back button is one named button', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpSubScreen(tester, build());
        expect(_single('뒤로가기'), _button);
        semantics.dispose();
      });
    }

    testWidgets('inquiry: the history icon and both fields are named', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpSubScreen(tester, const InquiryScreen());
      expect(_single('내 문의 내역'), _button);
      _field('제목');
      _field('문의 내용');
      semantics.dispose();
    });

    testWidgets('my inquiries: the write icon is named', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpSubScreen(tester, const MyInquiriesScreen());
      expect(_single('문의 작성'), _button);
      semantics.dispose();
    });

    testWidgets('notification and price alert switches are enabled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpSubScreen(tester, const NotificationSettingsScreen());
      expect(
        _single('전체 알림'),
        isSemantics(
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      expect(
        _single('가격 변동 알림'),
        isSemantics(hasToggledState: true, isEnabled: true),
      );

      await _pumpSubScreen(tester, const PriceAlertSubscriptionScreen());
      final toggles = find.semantics
          .byPredicate(
            (node) =>
                !node.isMergedIntoParent &&
                node.getSemanticsData().flagsCollection.isToggled !=
                    Tristate.none,
          )
          .evaluate();
      expect(toggles, isNotEmpty);
      for (final toggle in toggles) {
        expect(
          toggle,
          isSemantics(hasEnabledState: true, isEnabled: true),
          reason: toggle.getSemanticsData().label,
        );
      }
      semantics.dispose();
    });
  });

  testWidgets('MY shortcuts, rows, switches and recent reports (#50, #54)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    _phone(tester, height: 1200);
    await _pumpMypage(tester);

    for (final label in [
      '내 제보',
      '찜한 매장',
      '내 리뷰',
      '방문 기록',
      '절약 리포트',
      '전체보기',
      '계정 관리',
      '공공데이터 출처 안내',
      '문의하기',
    ]) {
      // The profile card shows '내 제보' and '찜한 매장' as plain text too.
      expect(_singleButton(label), _button, reason: label);
    }
    // The quick menu and the settings row both read '알림 설정'.
    final notificationSettings = _named('알림 설정').evaluate().toList();
    expect(notificationSettings, hasLength(2));
    for (final node in notificationSettings) {
      expect(node, _button);
    }
    expect(_containing('위치 권한 설정').single, _button);
    for (final label in ['이 기기 푸시 알림', '마케팅 정보 수신 동의']) {
      expect(
        _single(label),
        isSemantics(
          hasToggledState: true,
          isToggled: false,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
        reason: label,
      );
    }
    final recent = _containing('정장군숯불구이전문점').single;
    expect(recent, _button);
    semantics.dispose();
  });

  testWidgets('MY recent reports grow with large text instead of cutting '
      'the title or the rows (#5)', (tester) async {
    _phone(tester, height: 1200);
    final card = _byType('_ReportStatusCard');
    final settings = _byType('_SettingsCard');

    // The default text size keeps the design positions.
    await _pumpMypage(tester);
    expect(tester.getSize(card).height, moreOrLessEquals(189.23, epsilon: .5));
    expect(
      tester.getTopLeft(settings).dy - tester.getTopLeft(card).dy,
      moreOrLessEquals(201.22, epsilon: .5),
    );

    // About iOS accessibility-large. The test font is wider than the app
    // font, so rows outside this card overflow here too; only overflows inside
    // the card fail this test.
    final errors = <FlutterErrorDetails>[];
    final reportError = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await _pumpMypage(tester, textScale: 2);
    } finally {
      FlutterError.onError = reportError;
    }
    final cardBox = tester.renderObject(card);
    for (final error in errors) {
      final message = error.exceptionAsString();
      expect(message, contains('overflowed'), reason: '$error');
      expect(_reportedInside(error, cardBox), isFalse, reason: message);
    }

    for (final label in ['내 제보 상태', '전체보기']) {
      _expectTextFits(tester, find.text(label), inside: card);
    }
    final rows = _byType('_ReportItem');
    expect(rows, findsNWidgets(2));
    for (var index = 0; index < 2; index++) {
      final row = rows.at(index);
      final texts = find
          .descendant(of: row, matching: find.byType(RichText))
          .evaluate()
          .map((element) => find.byWidget(element.widget))
          .toList();
      expect(texts, hasLength(3), reason: 'store, summary and status');
      for (final text in texts) {
        // Long names may still end in an ellipsis; no line is cut.
        _expectTextFits(tester, text, inside: row, allowEllipsis: true);
      }
      final badge = find
          .ancestor(of: texts.last, matching: find.byType(Container))
          .first;
      expect(
        tester.getRect(texts.first).right,
        lessThanOrEqualTo(tester.getRect(badge).left + .5),
        reason: 'the store name runs under the status badge',
      );
    }
    expect(
      tester.getTopLeft(settings).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(card).dy),
      reason: 'the settings card is pushed down, not overlapped',
    );
    expect(tester.takeException(), isNull);
  });
}

Finder _byType(String name) =>
    find.byWidgetPredicate((widget) => '${widget.runtimeType}' == name);

/// Whether a render object inside [ancestor] reported [details].
bool _reportedInside(FlutterErrorDetails details, RenderObject ancestor) {
  final nodes = details.informationCollector?.call() ?? const [];
  return nodes.any((node) {
    final value = node.value;
    var object = value is RenderObject ? value : null;
    while (object != null) {
      if (identical(object, ancestor)) return true;
      object = object.parent;
    }
    return false;
  });
}

/// No line of [text] is clipped and it is drawn inside [inside]. Unless
/// [allowEllipsis], the whole text is shown.
void _expectTextFits(
  WidgetTester tester,
  Finder text, {
  required Finder inside,
  bool allowEllipsis = false,
}) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final label = paragraph.text.toPlainText();
  if (!allowEllipsis) {
    expect(paragraph.didExceedMaxLines, isFalse, reason: '"$label" is cut');
  }
  expect(
    paragraph.size.height,
    greaterThanOrEqualTo(
      paragraph.getMaxIntrinsicHeight(paragraph.size.width) - .5,
    ),
    reason: '"$label" is clipped vertically',
  );
  final rect = tester.getRect(text);
  final bounds = tester.getRect(inside).inflate(.5);
  expect(
    bounds.contains(rect.topLeft) && bounds.contains(rect.bottomRight),
    isTrue,
    reason: '"$label" $rect is outside $bounds',
  );
}

Future<void> _pumpMypage(WidgetTester tester, {double textScale = 1}) async {
  await http.runWithClient(
    () async {
      final router = GoRouter(
        initialLocation: '/mypage',
        routes: [
          GoRoute(path: '/mypage', builder: (_, _) => const MypageScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            reportServiceProvider.overrideWithValue(_reportService()),
            authStateProvider.overrideWith(
              (ref) => const AuthState(
                isLoggedIn: true,
                provider: '카카오',
                email: 'saver@example.com',
                sessionToken: 'qa-1007-a11y',
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    },
    () => MockClient(
      (request) async => http.Response(
        request.url.path == '/api/favorites' ? '[]' : '{}',
        200,
      ),
    ),
  );
}

/// Check boxes that would be read only by their value.
Iterable<SemanticsNode> _unnamedCheckboxes() =>
    find.semantics.byPredicate((node) {
      if (node.isMergedIntoParent) return false;
      final data = node.getSemanticsData();
      return data.flagsCollection.isChecked != CheckedState.none &&
          data.label.trim().isEmpty;
    }).evaluate();

Future<void> _pumpSubScreen(WidgetTester tester, Widget screen) async {
  _phone(tester);
  await http.runWithClient(
    () async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => screen),
          GoRoute(
            path: AppRoutes.inquiryHistory,
            builder: (_, _) => const Scaffold(body: Text('문의 내역')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            notificationSettingsApiServiceProvider.overrideWithValue(
              _SettingsApi(),
            ),
            priceAlertApiServiceProvider.overrideWithValue(_PriceApi()),
            inquiryServiceProvider.overrideWithValue(_Inquiries()),
            myInquiriesProvider.overrideWith((ref) async => const []),
            favoriteApiServiceProvider.overrideWithValue(_Favorites()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    },
    () => MockClient((request) async {
      if (request.url.path == '/api/visits') return _json([]);
      return http.Response('', 404);
    }),
  );
}

class _SettingsApi extends NotificationSettingsApiService {
  _SettingsApi() : super(MockClient((_) async => http.Response('{}', 500)));

  @override
  Future<NotificationSettings> fetchSettings() async =>
      NotificationSettings.defaults;
}

class _PriceApi extends PriceAlertApiService {
  _PriceApi() : super(MockClient((_) async => http.Response('{}', 500)));

  @override
  Future<PriceAlertSettings> fetchSettings() async => const PriceAlertSettings(
    all: true,
    stores: [
      PriceAlertStore(
        storeId: 'store-1',
        storeName: '검증 매장',
        menuName: '국수',
        enabled: true,
      ),
    ],
    notifyOnDrop: true,
    notifyOnRise: true,
    notifyOnNewMenu: false,
  );
}

class _Inquiries extends InquiryService {
  @override
  Future<List<Inquiry>> getMyInquiries() async => const [];
}

class _Favorites extends FavoriteApiService {
  @override
  Future<List<FavoriteStoreModel>> fetchFavorites() async => const [];
}

class _Reviews extends StoreReviewNotifier {
  @override
  Future<bool> addReview(Review review) async => false;
}
