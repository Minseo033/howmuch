import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:howmuch/app/app_routes.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/mypage/presentation/screens/inquiry_screen.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FlakyInquiryService extends InquiryService {
  _FlakyInquiryService();

  final created = <String>[];
  var storedAfterTimeout = true;

  @override
  Future<Map<String, dynamic>> createInquiry({
    required String title,
    required String content,
    String? category,
    List<String> imageUrls = const [],
  }) async {
    created.add(title);
    // The request timed out on the client, but the server stored it.
    return const {'error': true, 'message': '네트워크 연결을 확인하고 다시 시도해주세요.'};
  }

  @override
  Future<List<Inquiry>> getMyInquiries() async => [
    if (storedAfterTimeout)
      const Inquiry(
        id: 'inquiry-1',
        title: '지도 오류',
        content: '매장 위치가 달라요',
        category: '매장 정보 오류',
        status: 'PENDING',
        createdAt: '2026-10-06T00:00:00Z',
      ),
  ];
}

Future<void> _pumpInquiry(WidgetTester tester, InquiryService service) async {
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
      GoRoute(
        path: AppRoutes.inquiryHistory,
        builder: (_, _) => const Scaffold(body: Text('문의 내역')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [inquiryServiceProvider.overrideWithValue(service)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.tap(find.text('마이페이지'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // A member's inquiry; guests log in at send (mypage_guest_login_test).
    await ApiClient.setSessionToken('member-session');
  });
  tearDown(() => ApiClient.setSessionToken(null));

  testWidgets('a retry after a timeout does not send a duplicate inquiry', (
    tester,
  ) async {
    final service = _FlakyInquiryService();
    await _pumpInquiry(tester, service);

    await tester.enterText(find.byType(TextField).at(0), '지도 오류');
    await tester.enterText(find.byType(TextField).at(1), '매장 위치가 달라요');
    await tester.tap(find.text('문의 보내기'));
    await tester.pumpAndSettle();
    expect(find.text('네트워크 연결을 확인하고 다시 시도해주세요.'), findsOneWidget);
    // Let the snack bar leave so the retry tap reaches the button.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await tester.tap(find.text('문의 보내기'));
    await tester.pumpAndSettle();

    expect(service.created, ['지도 오류'], reason: 'the stored inquiry is found');
    expect(find.byType(InquiryScreen), findsNothing);
    expect(find.text('문의가 접수되었어요.'), findsOneWidget);
  });

  testWidgets('leaving a drafted inquiry asks before discarding it', (
    tester,
  ) async {
    await _pumpInquiry(tester, _FlakyInquiryService());

    await tester.enterText(find.byType(TextField).at(0), '작성 중');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('작성 중인 문의를 나갈까요?'), findsOneWidget);

    await tester.tap(find.text('계속 작성'));
    await tester.pumpAndSettle();
    expect(find.byType(InquiryScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('마이페이지'), findsOneWidget);
  });

  testWidgets('inquiry type chips expose the selected type', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpInquiry(tester, _FlakyInquiryService());

    expect(
      tester.getSemantics(find.text('매장 정보 오류')),
      isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    await tester.tap(find.text('기타'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.text('기타')), isSemantics(isSelected: true));
    expect(
      tester.getSemantics(find.text('매장 정보 오류')),
      isSemantics(isSelected: false),
    );
    semantics.dispose();
  });
}
