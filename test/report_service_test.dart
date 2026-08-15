import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/community/presentation/state/report_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.setSessionToken('test-session');
  });

  tearDown(() async {
    await ApiClient.setSessionToken(null);
  });

  test(
    'uploads JPEG bytes with an image/jpeg multipart content type',
    () async {
      late http.Request capturedRequest;
      final service = ReportService(
        MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'imageUrls': ['https://example.test/report.jpg'],
            }),
            200,
          );
        }),
      );
      final image = XFile.fromData(
        Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00]),
        name: 'camera-photo',
      );

      final urls = await service.uploadReportImages([image]);

      expect(urls, ['https://example.test/report.jpg']);
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/report/images');
      expect(
        capturedRequest.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(
        latin1.decode(capturedRequest.bodyBytes).toLowerCase(),
        contains('content-type: image/jpeg'),
      );
    },
  );

  test(
    'rejects disguised or unsupported files before network upload',
    () async {
      final service = ReportService(
        MockClient((_) async => fail('network request must not be sent')),
      );
      final svg = XFile.fromData(
        Uint8List.fromList(utf8.encode('<svg><script /></svg>')),
        name: 'photo.jpg',
      );

      await expectLater(
        service.uploadReportImages([svg]),
        throwsA(
          isA<ReportServiceException>().having(
            (error) => error.message,
            'message',
            contains('JPEG, PNG, WebP'),
          ),
        ),
      );
    },
  );

  test('rejects more than three images before network upload', () async {
    final service = ReportService(
      MockClient((_) async => fail('network request must not be sent')),
    );
    final images = List.generate(
      4,
      (index) => XFile.fromData(
        Uint8List.fromList([0xFF, 0xD8, 0xFF, index]),
        name: 'photo-$index.jpg',
      ),
    );

    await expectLater(
      service.uploadReportImages(images),
      throwsA(isA<ReportServiceException>()),
    );
  });

  test('deletes a report with the authenticated API contract', () async {
    late http.Request capturedRequest;
    final service = ReportService(
      MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'success': true, 'id': 'report 1', 'deletedImages': 2}),
          200,
        );
      }),
    );

    final deletedImages = await service.deleteReport('report 1');

    expect(deletedImages, 2);
    expect(capturedRequest.method, 'DELETE');
    expect(capturedRequest.url.path, '/api/report/store/report%201');
    expect(capturedRequest.headers['authorization'], 'Bearer test-session');
  });

  test(
    'surfaces a safe server message when report deletion is forbidden',
    () async {
      final service = ReportService(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'success': false, 'message': '본인의 제보만 삭제할 수 있습니다.'}),
            403,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await expectLater(
        service.deleteReport('report-1'),
        throwsA(
          isA<ReportServiceException>()
              .having((error) => error.statusCode, 'statusCode', 403)
              .having((error) => error.message, 'message', contains('본인의 제보')),
        ),
      );
    },
  );

  test('requires authentication before deleting a report', () async {
    await ApiClient.setSessionToken(null);
    final service = ReportService(
      MockClient((_) async => fail('network request must not be sent')),
    );

    await expectLater(
      service.deleteReport('report-1'),
      throwsA(
        isA<ReportServiceException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });
}
