import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';

void main() {
  test('maps an answered inquiry without falling back to sample data', () {
    final inquiry = Inquiry.fromJson({
      'id': 'inquiry-1',
      'title': '가격 정보 확인 요청',
      'content': '가격을 확인해주세요.',
      'category': '매장 정보 오류',
      'status': 'ANSWERED',
      'createdAt': '2026-08-13T01:00:00Z',
      'answer': '확인 후 수정했습니다.',
      'answeredAt': '2026-08-13T02:00:00Z',
    });

    expect(inquiry.id, 'inquiry-1');
    expect(inquiry.isAnswered, isTrue);
    expect(inquiry.answer, '확인 후 수정했습니다.');
  });

  test('recognizes an answered status before the answer text is loaded', () {
    final inquiry = Inquiry.fromJson({'status': 'ANSWERED'});

    expect(inquiry.status, 'ANSWERED');
    expect(inquiry.isAnswered, isTrue);
  });
}
