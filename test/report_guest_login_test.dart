import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/auth/presentation/screens/login_screen.dart';
import 'package:howmuch/features/auth/presentation/state/auth_state.dart';
import 'package:howmuch/features/auth/presentation/state/kakao_login_service.dart';
import 'package:howmuch/features/auth/presentation/state/login_flow.dart';
import 'package:howmuch/features/community/presentation/screens/report_complete_screen.dart';
import 'package:howmuch/features/community/presentation/screens/report_create_screen.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
const _session = 'guest-report-session';
const _uploadedPhoto = 'https://cdn.example.com/menu.png';
const _checks = ['최근 1개월 이내 방문했어요', '메뉴판 가격을 직접 확인했어요'];

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

/// Kakao login that succeeds at once for an existing account and, like the
/// real service, marks the visitor as logged in.
class _FakeLoginService extends KakaoLoginService {
  _FakeLoginService(this.ref) : super(ref);

  final Ref ref;
  final navigateRequests = <bool>[];

  @override
  Future<KakaoLoginResult> login({bool navigate = true}) async {
    navigateRequests.add(navigate);
    await ApiClient.setSessionToken(_session);
    ref.read(authStateProvider.notifier).state = const AuthState(
      isLoggedIn: true,
      provider: '카카오',
      email: '',
    );
    return const KakaoLoginResult(KakaoLoginStatus.success);
  }
}

/// Opens the new report form as a guest on top of a community stand-in.
Future<({List<http.Request> requests, _FakeLoginService login})> _openForm(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final requests = <http.Request>[];
  final service = ReportService(
    MockClient((request) async {
      requests.add(request);
      return switch (request.url.path) {
        '/api/report/images' => _json({
          'imageUrls': [_uploadedPhoto],
        }),
        '/api/report/store' => _json({'success': true, 'reportId': 'guest-1'}),
        '/api/report/my' => _json([
          {
            'id': 'guest-1',
            'storeName': '새 식당',
            'address': '서울 구로구 중앙로 1',
            'industry': '음식점 · 한식',
            'menu1': '국수',
            'price1': '5000',
            'imageUrls': [_uploadedPhoto],
            'status': 'PENDING',
            'createdAt': '2026-10-10T01:00:00Z',
          },
        ]),
        _ => _json({}, 404),
      };
    }),
  );
  final container = ProviderContainer(
    overrides: [
      reportServiceProvider.overrideWithValue(service),
      kakaoLoginServiceProvider.overrideWith((ref) => _FakeLoginService(ref)),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('커뮤니티 자리')),
      ),
      GoRoute(
        path: AppRoutes.reportCreate,
        builder: (_, _) => ReportCreateScreen(
          locationLookup: () async => null,
          placeSearch: (_, _, _) async => const [
            ReportPlaceSuggestion(
              name: '새 식당',
              address: '서울 구로구 중앙로 1',
              category: '음식점 > 한식',
            ),
          ],
          photoPicker: () async => XFile.fromData(
            base64Decode(_onePixelPng),
            name: 'menu.png',
            path: '/tmp/howmuch-guest-menu.png',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, state) => LoginScreen(entry: loginEntryOf(state.extra)),
      ),
      GoRoute(
        path: AppRoutes.reportComplete,
        builder: (_, state) =>
            ReportCompleteScreen(reportId: state.uri.queryParameters['id']),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push(AppRoutes.reportCreate);
  await tester.pumpAndSettle();
  return (
    requests: requests,
    login: container.read(kakaoLoginServiceProvider) as _FakeLoginService,
  );
}

/// Fills in the whole report: store, menu, a photo and both checks.
Future<void> _fillReport(WidgetTester tester) async {
  await tester.tap(find.byTooltip('매장 검색'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('report-address-search-input')),
    '새 식당',
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(ListTile), matching: find.text('새 식당')),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(3), '국수');
  await tester.enterText(find.byType(TextField).at(4), '5000');
  for (final label in ['메뉴판 사진 첨부', ..._checks]) {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('제보 제출하기'));
  await tester.tap(find.text('제보 제출하기'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      authTermsAcceptedPreferenceKey: true,
    });
    await ApiClient.setSessionToken(null);
  });
  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets('choosing later keeps the filled report and sends nothing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final (:requests, :login) = await _openForm(tester);
    await _fillReport(tester);
    await _tapSubmit(tester);

    expect(find.text('로그인이 필요해요'), findsOneWidget);
    expect(find.text('제보는 로그인 후 보낼 수 있어요. 작성한 내용은 그대로 있어요.'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();

    expect(find.text('로그인이 필요해요'), findsNothing);
    for (final value in [
      '새 식당',
      '음식점 · 한식',
      '서울 구로구 중앙로 1',
      '국수',
      '5000',
      '사진 1장 첨부됨',
    ]) {
      expect(find.text(value), findsOneWidget, reason: value);
    }
    for (final label in _checks) {
      expect(
        find.semantics.byLabel(label).evaluate().single,
        isSemantics(isChecked: true),
        reason: label,
      );
    }
    expect(requests, isEmpty);
    expect(login.navigateRequests, isEmpty);
    expect(ApiClient.isAuthenticated, isFalse);
    semantics.dispose();
  });

  testWidgets('logging in at submit sends the same report with its photo', (
    tester,
  ) async {
    final (:requests, :login) = await _openForm(tester);
    await _fillReport(tester);
    await _tapSubmit(tester);

    await tester.tap(find.byKey(const Key('login_required_confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(requests, isEmpty);

    await tester.tap(find.text('카카오로 계속하기'));
    await tester.pumpAndSettle();

    expect(login.navigateRequests, [false]);
    expect(find.text('제보가 접수되었어요'), findsOneWidget);
    expect(find.byType(ReportCreateScreen), findsNothing);
    final upload = requests.singleWhere(
      (request) => request.url.path == '/api/report/images',
    );
    expect(upload.headers['Authorization'], 'Bearer $_session');
    final post = requests.singleWhere(
      (request) =>
          request.method == 'POST' && request.url.path == '/api/report/store',
    );
    expect(post.headers['Authorization'], 'Bearer $_session');
    final body = jsonDecode(post.body) as Map<String, dynamic>;
    expect(body['storeName'], '새 식당');
    expect(body['industry'], '음식점 · 한식');
    expect(body['address'], '서울 구로구 중앙로 1');
    expect(body['menu1'], '국수');
    expect(body['price1'], '5000');
    expect(body['imageUrls'], [_uploadedPhoto]);
    expect(body['visitedRecently'], isTrue);
    expect(body['checkedMenuPrice'], isTrue);
  });

  testWidgets('the guest tip logs in over the form and keeps what was typed', (
    tester,
  ) async {
    final (:requests, :login) = await _openForm(tester);
    await tester.enterText(find.byType(TextField).first, '게스트 식당');
    expect(
      find.text('제보는 로그인 후 보낼 수 있어요.\n여기를 눌러 미리 로그인할 수도 있어요.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('report-guest-login-tip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카카오로 계속하기'));
    await tester.pumpAndSettle();

    expect(login.navigateRequests, [false]);
    expect(find.byType(ReportCreateScreen), findsOneWidget);
    expect(find.text('게스트 식당'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-guest-login-tip')), findsNothing);
    expect(requests, isEmpty);
  });
}
