import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/screens/visit_history_screen.dart';

void main() {
  test('formats location and receipt verification methods', () {
    expect(formatVisitVerification('LOCATION', 49.6), '위치 인증 · 50m');
    expect(formatVisitVerification('RECEIPT_OCR', null), '영수증 OCR 인증');
    expect(formatVisitVerification('UNKNOWN', null), isNull);
  });
}
