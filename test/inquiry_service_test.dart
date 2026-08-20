import 'package:flutter_test/flutter_test.dart';
import 'package:howmuch/features/mypage/presentation/state/inquiry_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

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
      'imageUrls': [
        'https://res.cloudinary.com/demo/image/upload/inquiry.jpg',
        'javascript:alert(1)',
      ],
    });

    expect(inquiry.id, 'inquiry-1');
    expect(inquiry.isAnswered, isTrue);
    expect(inquiry.answer, '확인 후 수정했습니다.');
    expect(inquiry.imageUrls, [
      'https://res.cloudinary.com/demo/image/upload/inquiry.jpg',
    ]);
  });

  test('recognizes an answered status before the answer text is loaded', () {
    final inquiry = Inquiry.fromJson({'status': 'ANSWERED'});

    expect(inquiry.status, 'ANSWERED');
    expect(inquiry.isAnswered, isTrue);
  });

  test('sends uploaded image URLs in the inquiry request', () async {
    late http.Request captured;
    final service = InquiryService(
      MockClient((request) async {
        captured = request;
        return http.Response('{"id":"inquiry-1","status":"PENDING"}', 200);
      }),
    );

    final result = await service.createInquiry(
      title: '사진 문의',
      content: '첨부를 확인해주세요.',
      category: '기타',
      imageUrls: const ['https://res.cloudinary.com/demo/inquiry.jpg'],
    );

    expect(captured.url.path, '/api/inquiry');
    expect(jsonDecode(captured.body)['imageUrls'], [
      'https://res.cloudinary.com/demo/inquiry.jpg',
    ]);
    expect(result['id'], 'inquiry-1');
  });

  test(
    'only requests image cleanup for an explicit client rejection',
    () async {
      final rejected = InquiryService(
        MockClient((_) async => http.Response('{}', 400)),
      );
      final unavailable = InquiryService(
        MockClient((_) async => http.Response('{}', 500)),
      );

      expect(
        (await rejected.createInquiry(
          title: '문의',
          content: '내용',
        ))['cleanupUploadedImages'],
        isTrue,
      );
      expect(
        (await unavailable.createInquiry(
          title: '문의',
          content: '내용',
        ))['cleanupUploadedImages'],
        isFalse,
      );
    },
  );
}
