import 'package:flutter_test/flutter_test.dart';
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
  });
}
