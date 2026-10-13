import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/presentation/screens/visit_verification_screen.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:howmuch/shared/widgets/custom_bottom_button.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestGeolocator extends GeolocatorPlatform {
  double latitude = 37.5;
  LocationPermission permission = LocationPermission.whileInUse;
  int positionRequests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positionRequests++;
    return Position(
      latitude: latitude,
      longitude: 126.86,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

Store _store({String price = '5500', bool free = false}) => Store(
  id: 'receipt-demo-store',
  storeName: '캠퍼스분식',
  address: '서울 구로구 경인로 445',
  phoneNumber: '',
  industry: '한식',
  menu1: '김치찌개',
  price1: price,
  free1: free,
  menu2: '',
  price2: '',
  menu3: '',
  price3: '',
  menu4: '',
  price4: '',
  latitude: 37.5,
  longitude: 126.86,
  source: 'USER',
);

void main() {
  const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
  late GeolocatorPlatform originalGeolocator;
  late _TestGeolocator geolocator;
  late Directory imageDirectory;
  late File receiptImage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('receipt-test-session');
    originalGeolocator = GeolocatorPlatform.instance;
    geolocator = _TestGeolocator();
    GeolocatorPlatform.instance = geolocator;
    imageDirectory = Directory.systemTemp.createTempSync(
      'receipt-submit-test-',
    );
    receiptImage = File('${imageDirectory.path}/receipt.png')
      ..writeAsBytesSync([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (call) async {
          expect(call.method, 'pickImage');
          return receiptImage.path;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, null);
    GeolocatorPlatform.instance = originalGeolocator;
    imageDirectory.deleteSync(recursive: true);
    await ApiClient.setSessionToken(null);
  });

  CustomBottomButton bottomButton(WidgetTester tester) =>
      tester.widget<CustomBottomButton>(find.byType(CustomBottomButton));

  Future<void> prepare(
    WidgetTester tester, {
    Store? store,
    bool verifyLocation = true,
    bool selectReceipt = true,
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: VisitVerificationScreen(store: store ?? _store())),
    );
    await tester.pumpAndSettle();
    if (verifyLocation) {
      await tester.tap(find.text('현재 위치 확인'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byType(ActionChip).first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    if (selectReceipt) {
      await tester.tap(find.byTooltip('영수증 사진 선택'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> waitForIo(WidgetTester tester, bool Function() done) async {
    // File IO runs outside the widget test clock; flush both queues without
    // awaiting a completer across the real and fake async zones.
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(done(), isTrue);
    await tester.pumpAndSettle();
  }

  http.StreamedResponse response(String status, {int statusCode = 200}) =>
      http.StreamedResponse(Stream.value(utf8.encode(status)), statusCode);

  http.Client estimatesOnly(List<String> posted) =>
      MockClient.streaming((request, _) async {
        if (request.method == 'POST') posted.add(request.url.path);
        return response('{"savedAmount":0,"referencePriceAvailable":false}');
      });

  for (final size in [const Size(320, 568), const Size(852, 393)]) {
    testWidgets('required proof controls fit at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: VisitVerificationScreen(store: _store())),
      );
      await tester.pumpAndSettle();
      expect(bottomButton(tester).text, '위치 확인이 필요해요');
      expect(bottomButton(tester).onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('location alone cannot record a visit', (tester) async {
    final posted = <String>[];
    await http.runWithClient(() async {
      await prepare(tester, selectReceipt: false);
      expect(bottomButton(tester).text, '영수증 사진을 선택해주세요');
      expect(bottomButton(tester).onPressed, isNull);
      await tester.tap(find.byType(CustomBottomButton));
      await tester.pumpAndSettle();
      expect(posted, isEmpty);
    }, () => estimatesOnly(posted));
  });

  testWidgets('a receipt alone cannot bypass location verification', (
    tester,
  ) async {
    final posted = <String>[];
    await http.runWithClient(() async {
      await prepare(tester, verifyLocation: false);
      expect(bottomButton(tester).onPressed, isNull);
      geolocator.permission = LocationPermission.deniedForever;
      await tester.tap(find.text('현재 위치 확인'));
      await tester.pumpAndSettle();
      expect(find.text('설정에서 위치 권한을 허용해주세요.'), findsOneWidget);
      expect(bottomButton(tester).onPressed, isNull);
      expect(posted, isEmpty);
    }, () => estimatesOnly(posted));
  });

  for (final status in ['PENDING', 'APPROVED']) {
    testWidgets(
      'location plus receipt submits once and shows $status accurately',
      (tester) async {
        final submitted = Completer<void>();
        final posted = <String>[];
        Map<String, String>? receiptFields;
        final receiptResponse = Completer<http.StreamedResponse>();
        await http.runWithClient(
          () async {
            await prepare(tester);
            expect(bottomButton(tester).text, '영수증 인증 제출');
            expect(bottomButton(tester).onPressed, isNotNull);
            await tester.tap(find.byType(CustomBottomButton));
            await waitForIo(tester, () => submitted.isCompleted);
            expect(posted, ['/api/visits/receipt']);
            expect(receiptFields, {
              'storeId': 'receipt-demo-store',
              'storeName': '캠퍼스분식',
              'menu': '김치찌개',
              'price': '5500',
              'latitude': '37.5',
              'longitude': '126.86',
              'locationAccuracyMeters': '5.0',
            });
            expect(geolocator.positionRequests, 2);
            expect(bottomButton(tester).text, '영수증 제출 중…');
            expect(bottomButton(tester).onPressed, isNull);
            expect(find.text('취소'), findsNothing);
            expect(
              tester
                  .widget<IconButton>(
                    find.byWidgetPredicate(
                      (widget) =>
                          widget is IconButton && widget.tooltip == '영수증 사진 선택',
                    ),
                  )
                  .onPressed,
              isNull,
            );
            await tester.tap(find.byType(CustomBottomButton));
            await tester.pump();
            expect(posted, hasLength(1));
            receiptResponse.complete(response('{"status":"$status"}'));
            await tester.pumpAndSettle();
            expect(
              bottomButton(tester).text,
              status == 'PENDING' ? '영수증 검토 대기 중' : '영수증 인증 완료',
            );
            expect(bottomButton(tester).onPressed, isNull);
            expect(
              find.text(
                status == 'PENDING'
                    ? '영수증 인증을 신청했어요. 관리자 확인 후 반영됩니다.'
                    : '영수증 인증이 완료되어 방문 기록에 반영됐어요.',
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
          () => MockClient.streaming((request, _) async {
            if (request.method == 'POST') posted.add(request.url.path);
            if (request.url.path == '/api/visits/receipt') {
              final multipart = request as http.MultipartRequest;
              receiptFields = Map.of(multipart.fields);
              expect(multipart.files.single.field, 'images');
              expect(multipart.files.single.length, 8);
              expect(
                multipart.headers['Authorization'],
                'Bearer receipt-test-session',
              );
              submitted.complete();
              return receiptResponse.future;
            }
            return response(
              '{"savedAmount":0,"referencePriceAvailable":false}',
            );
          }),
        );
      },
    );
  }

  testWidgets('moving away after a location check blocks receipt submission', (
    tester,
  ) async {
    final posted = <String>[];
    await http.runWithClient(() async {
      await prepare(tester);
      geolocator.latitude = 37.502;
      await tester.tap(find.byType(CustomBottomButton));
      await waitForIo(tester, () => geolocator.positionRequests == 2);
      expect(posted, isEmpty);
      expect(bottomButton(tester).onPressed, isNull);
      expect(find.textContaining('100m 이내에서 인증할 수 있어요.'), findsWidgets);
    }, () => estimatesOnly(posted));
  });

  testWidgets(
    'cancelling a receipt keeps location but requires a new receipt',
    (tester) async {
      await http.runWithClient(() async {
        await prepare(tester);
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(bottomButton(tester).text, '영수증 사진을 선택해주세요');
        expect(bottomButton(tester).onPressed, isNull);
      }, () => estimatesOnly([]));
    },
  );

  testWidgets('approved free menus also require and submit a receipt for 0원', (
    tester,
  ) async {
    Map<String, String>? fields;
    await http.runWithClient(
      () async {
        await prepare(tester, store: _store(price: '0', free: true));
        expect(bottomButton(tester).onPressed, isNotNull);
        await tester.tap(find.byType(CustomBottomButton));
        await waitForIo(tester, () => fields != null);
        expect(fields!['price'], '0');
        expect(fields!['latitude'], '37.5');
        expect(bottomButton(tester).text, '영수증 검토 대기 중');
      },
      () => MockClient.streaming((request, _) async {
        if (request.method == 'POST') {
          expect(request.url.path, '/api/visits/receipt');
          fields = Map.of((request as http.MultipartRequest).fields);
          return response('{"status":"PENDING"}');
        }
        return response('{"savedAmount":0,"referencePriceAvailable":false}');
      }),
    );
  });

  testWidgets(
    'a paid menu with zero amount remains blocked despite both proofs',
    (tester) async {
      final posted = <String>[];
      await http.runWithClient(() async {
        await prepare(tester, store: _store(price: '0'));
        expect(bottomButton(tester).onPressed, isNull);
        expect(posted, isEmpty);
      }, () => estimatesOnly(posted));
    },
  );

  testWidgets('a rejected upload keeps the receipt available for correction', (
    tester,
  ) async {
    bool posted = false;
    await http.runWithClient(
      () async {
        await prepare(tester);
        await tester.tap(find.byType(CustomBottomButton));
        await waitForIo(tester, () => posted);
        expect(find.text('결제 금액을 확인해주세요.'), findsOneWidget);
        expect(bottomButton(tester).onPressed, isNotNull);
        expect(find.text('취소'), findsOneWidget);
      },
      () => MockClient.streaming((request, _) async {
        if (request.method == 'POST') {
          posted = true;
          return response('{"message":"결제 금액을 확인해주세요."}', statusCode: 400);
        }
        return response('{"savedAmount":0,"referencePriceAvailable":false}');
      }),
    );
  });
}
