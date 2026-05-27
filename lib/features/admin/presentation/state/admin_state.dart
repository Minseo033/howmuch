import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ReviewStatus { pending, approved, rejected, answered }

extension ReviewStatusLabel on ReviewStatus {
  String get label {
    return switch (this) {
      ReviewStatus.pending => '검토 중',
      ReviewStatus.approved => '승인',
      ReviewStatus.rejected => '반려',
      ReviewStatus.answered => '답변 완료',
    };
  }
}

class AdminReport {
  const AdminReport({
    required this.id,
    required this.storeName,
    required this.category,
    required this.address,
    required this.message,
    required this.status,
  });

  final String id;
  final String storeName;
  final String category;
  final String address;
  final String message;
  final ReviewStatus status;

  AdminReport copyWith({ReviewStatus? status}) {
    return AdminReport(
      id: id,
      storeName: storeName,
      category: category,
      address: address,
      message: message,
      status: status ?? this.status,
    );
  }
}

class AdminInquiry {
  const AdminInquiry({
    required this.id,
    required this.title,
    required this.author,
    required this.message,
    required this.status,
  });

  final String id;
  final String title;
  final String author;
  final String message;
  final ReviewStatus status;

  AdminInquiry copyWith({ReviewStatus? status}) {
    return AdminInquiry(
      id: id,
      title: title,
      author: author,
      message: message,
      status: status ?? this.status,
    );
  }
}

final reportStatusFilterProvider = StateProvider<ReviewStatus?>((ref) => null);
final inquiryStatusFilterProvider = StateProvider<ReviewStatus?>((ref) => null);

final adminReportsProvider = StateProvider<List<AdminReport>>(
  (ref) => const [
    AdminReport(
      id: 'R-1021',
      storeName: '성산동 김밥집',
      category: '분식',
      address: '서울 마포구 성산동',
      message: '라면 3,500원 메뉴가 새로 생겼습니다.',
      status: ReviewStatus.pending,
    ),
    AdminReport(
      id: 'R-1018',
      storeName: '연남 국수',
      category: '한식',
      address: '서울 마포구 연남동',
      message: '착한가격업소 표지판이 확인됩니다.',
      status: ReviewStatus.approved,
    ),
    AdminReport(
      id: 'R-1012',
      storeName: '홍대 커피집',
      category: '카페',
      address: '서울 마포구 서교동',
      message: '가격표 사진이 흐려 확인이 어렵습니다.',
      status: ReviewStatus.rejected,
    ),
  ],
);

final adminInquiriesProvider = StateProvider<List<AdminInquiry>>(
  (ref) => const [
    AdminInquiry(
      id: 'Q-220',
      title: '가격 정보 수정 요청',
      author: '민서',
      message: '매장 상세의 김치찌개 가격이 실제와 다릅니다.',
      status: ReviewStatus.pending,
    ),
    AdminInquiry(
      id: 'Q-218',
      title: '리뷰 삭제 문의',
      author: '익명 사용자',
      message: '잘못 작성한 리뷰를 삭제하고 싶습니다.',
      status: ReviewStatus.answered,
    ),
  ],
);
