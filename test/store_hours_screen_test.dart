import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/presentation/screens/store_detail_screen.dart';
import 'package:howmuch/features/store/presentation/state/store_review_state.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LocalReviews extends StoreReviewNotifier {
  @override
  Future<void> loadReviews(String storeId, {bool force = false}) async {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken(null);
  });

  for (final width in [375.0, 820.0]) {
    testWidgets('source-backed hours wrap safely at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = Store.fromJson({
        'storeName': '와고숯불구이',
        'address': '서울특별시 강동구 천호옛14길 37',
        'openingHours': {
          'status': 'SOURCE_VERIFIED',
          'text': '월~금 17:00~23:00\n토 16:00~23:00\n일요일 휴무',
          'sourceName': '행정안전부 착한가격업소',
          'sourceUrl':
              'https://www.goodprice.go.kr/bssh/bsshInfo.do?bsshSn=17427',
          'checkedAt': '2026-09-12',
          'imageUrls': [
            'https://www.goodprice.go.kr/comm/showImageFile.do?fileCours=/bssh/20251028/&fileId=store.jpg',
          ],
        },
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeReviewProvider.overrideWith((ref) => _LocalReviews()),
          ],
          child: MaterialApp(home: StoreDetailScreen(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final imageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == '와고숯불구이 매장 사진 1',
      );
      final image = tester.widget<Image>(imageFinder);
      final provider = image.image as NetworkImage;
      expect(provider.webHtmlElementStrategy, WebHtmlElementStrategy.prefer);
      expect(image.width, closeTo(335.4545, 0.01));
      expect(image.height, 210);
      await tester.ensureVisible(find.textContaining('월~금 17:00'));
      expect(find.textContaining('2026.09.12 자료 조회'), findsOneWidget);
      expect(find.text('등록된 영업시간이 없어요.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'missing hours show honest guidance without an extra load button',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storeReviewProvider.overrideWith((ref) => _LocalReviews()),
          ],
          child: MaterialApp(
            home: StoreDetailScreen(
              store: Store.fromJson({'storeName': '시간 미제공 매장'}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('등록된 영업시간이 없어요.'));
      expect(find.text('방문 전 최신 안내를 확인해 주세요.'), findsOneWidget);
      expect(find.text('불러오기'), findsNothing);
      expect(find.text('영업 중'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
