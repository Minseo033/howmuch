import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/presentation/screens/visit_verification_screen.dart';
import 'package:howmuch/features/store/presentation/state/visit_verification_policy.dart';

void main() {
  group('VisitVerificationPolicy', () {
    test('accepts usable store coordinates only', () {
      expect(
        VisitVerificationPolicy.hasValidStoreCoordinates(35.1379, 129.1012),
        isTrue,
      );
      expect(VisitVerificationPolicy.hasValidStoreCoordinates(0, 0), isFalse);
      expect(
        VisitVerificationPolicy.hasValidStoreCoordinates(91, 129.1012),
        isFalse,
      );
    });

    test('uses a 50 meter location verification radius', () {
      expect(VisitVerificationPolicy.isWithinVerificationRadius(0), isTrue);
      expect(VisitVerificationPolicy.isWithinVerificationRadius(50), isTrue);
      expect(VisitVerificationPolicy.isWithinVerificationRadius(50.1), isFalse);
    });

    test('rejects inaccurate or invalid location readings', () {
      expect(VisitVerificationPolicy.hasUsableLocationAccuracy(50), isTrue);
      expect(VisitVerificationPolicy.hasUsableLocationAccuracy(50.1), isFalse);
      expect(
        VisitVerificationPolicy.hasUsableLocationAccuracy(double.nan),
        isFalse,
      );
      expect(VisitVerificationPolicy.hasUsableLocationAccuracy(-1), isFalse);
    });

    test('rejects stale or future location readings', () {
      final now = DateTime.utc(2026, 8, 19, 12);
      expect(
        VisitVerificationPolicy.isFreshLocation(
          now.subtract(const Duration(seconds: 30)),
          now,
        ),
        isTrue,
      );
      expect(
        VisitVerificationPolicy.isFreshLocation(
          now.subtract(const Duration(seconds: 31)),
          now,
        ),
        isFalse,
      );
      expect(
        VisitVerificationPolicy.isFreshLocation(
          now.add(const Duration(seconds: 1)),
          now,
        ),
        isFalse,
      );
    });
  });

  group('receiptSubmissionErrorMessage', () {
    test('shows the backend validation message when available', () {
      expect(
        receiptSubmissionErrorMessage(
          400,
          '{"success":false,"message":"JPEG, PNG, WebP 형식만 지원합니다."}',
        ),
        'JPEG, PNG, WebP 형식만 지원합니다.',
      );
    });

    test('uses a useful fallback for oversized proxy responses', () {
      expect(
        receiptSubmissionErrorMessage(413, '<html>too large</html>'),
        '영수증 사진은 5MB 이하로 선택해주세요.',
      );
    });
  });

  group('visitSubmissionErrorMessage', () {
    test('shows duplicate visit conflicts returned by the backend', () {
      expect(
        visitSubmissionErrorMessage(
          409,
          '{"success":false,"message":"오늘 이미 이 매장의 방문 인증을 완료했습니다."}',
        ),
        '오늘 이미 이 매장의 방문 인증을 완료했습니다.',
      );
    });
  });

  group('receipt image request policy', () {
    test('accepts only supported binary signatures', () {
      expect(receiptImageExtension([0xFF, 0xD8, 0xFF, 0x00]), 'jpg');
      expect(
        receiptImageExtension([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        'png',
      );
      expect(
        receiptImageExtension([
          0x52,
          0x49,
          0x46,
          0x46,
          0,
          0,
          0,
          0,
          0x57,
          0x45,
          0x42,
          0x50,
        ]),
        'webp',
      );
      expect(receiptImageExtension([1, 2, 3, 4]), isNull);
    });

    test('allows more time than an ordinary API request', () {
      expect(receiptSubmissionTimeout, greaterThan(ApiClient.defaultTimeout));
      expect(maxReceiptImageBytes, 5 * 1024 * 1024);
    });
  });
}
