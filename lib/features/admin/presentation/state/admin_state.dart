import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AdminReviewStatus {
  fresh('신규'),
  reviewing('검토 중'),
  approved('승인'),
  rejected('반려'),
  revision('보완 요청');

  const AdminReviewStatus(this.label);

  final String label;
}

class AdminReportReview {
  const AdminReportReview({
    required this.id,
    required this.storeName,
    required this.category,
    required this.reporter,
    required this.createdAt,
    required this.menuName,
    required this.price,
    required this.photoCount,
    required this.address,
    required this.memo,
    required this.status,
    required this.checks,
  });

  final String id;
  final String storeName;
  final String category;
  final String reporter;
  final String createdAt;
  final String menuName;
  final int price;
  final int photoCount;
  final String address;
  final String memo;
  final AdminReviewStatus status;
  final List<bool> checks;

  String get priceText =>
      '${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}원';

  int get completedChecks => checks.where((checked) => checked).length;

  AdminReportReview copyWith({AdminReviewStatus? status, List<bool>? checks}) {
    return AdminReportReview(
      id: id,
      storeName: storeName,
      category: category,
      reporter: reporter,
      createdAt: createdAt,
      menuName: menuName,
      price: price,
      photoCount: photoCount,
      address: address,
      memo: memo,
      status: status ?? this.status,
      checks: checks ?? this.checks,
    );
  }
}

enum AdminInquiryStatus {
  waiting('대기'),
  inProgress('처리 중'),
  completed('답변 완료');

  const AdminInquiryStatus(this.label);

  final String label;
}

class AdminInquiry {
  const AdminInquiry({
    required this.id,
    required this.type,
    required this.status,
    required this.elapsed,
    required this.title,
    required this.body,
    required this.author,
    this.answer,
  });

  final String id;
  final String type;
  final AdminInquiryStatus status;
  final String elapsed;
  final String title;
  final String body;
  final String author;
  final String? answer;

  AdminInquiry copyWith({AdminInquiryStatus? status, String? answer}) {
    return AdminInquiry(
      id: id,
      type: type,
      status: status ?? this.status,
      elapsed: elapsed,
      title: title,
      body: body,
      author: author,
      answer: answer ?? this.answer,
    );
  }
}

// TODO(박지환 BE): 관리자 제보 검토 목록 API 응답으로 교체하세요.
final adminReportsProvider = StateProvider<List<AdminReportReview>>(
  (ref) => const [
    AdminReportReview(
      id: '2026-0512-019',
      storeName: '골목밥상',
      category: '음식점 · 한식',
      reporter: '절약왕 민서',
      createdAt: '2026.05.12',
      menuName: '제육덮밥',
      price: 6000,
      photoCount: 4,
      address: '서울시 강남구 역삼동 123-4',
      memo: '점심 시간에도 6,000원으로 판매 중인 메뉴예요.',
      status: AdminReviewStatus.fresh,
      checks: [true, true, false, true],
    ),
    AdminReportReview(
      id: '2026-0512-020',
      storeName: '동네카페',
      category: '카페 · 음료',
      reporter: '동네탐험가',
      createdAt: '2026.05.12',
      menuName: '아메리카노',
      price: 2000,
      photoCount: 2,
      address: '서울시 마포구 합정동 77-1',
      memo: '평일 오전 가격표 기준입니다.',
      status: AdminReviewStatus.reviewing,
      checks: [true, false, true, true],
    ),
  ],
);

// TODO(박지환 BE): 관리자 문의 검토 목록 API 응답으로 교체하세요.
final adminInquiriesProvider = StateProvider<List<AdminInquiry>>(
  (ref) => const [
    AdminInquiry(
      id: 'Q-0512-031',
      type: '제보 검토 문의',
      status: AdminInquiryStatus.waiting,
      elapsed: '32분 전',
      title: '제보한 매장이 7일째 검토 중이에요',
      body:
          '합정역 골목밥상 제보를 5월 10일에 등록했는데 아직 검토 중 상태예요. 다른 분들도 같은 매장 제보하신 것 같던데 언제쯤 확인될까요?',
      author: '절약왕민수',
    ),
    AdminInquiry(
      id: 'Q-0512-032',
      type: '버그 신고',
      status: AdminInquiryStatus.waiting,
      elapsed: '2시간 전',
      title: '지도에서 마커가 사라져요',
      body: '안드로이드에서 줌인하면 일부 매장 마커가 깜빡이다 사라집니다. 갤럭시 S23 Android 14입니다.',
      author: '동네탐험가',
    ),
    AdminInquiry(
      id: 'Q-0512-033',
      type: '기능 제안',
      status: AdminInquiryStatus.inProgress,
      elapsed: '6시간 전',
      title: '여러 명이 함께 보는 찜 폴더가 있으면 좋겠어요',
      body: '가족이나 친구끼리 공유할 수 있는 찜 리스트 기능을 추가해주세요. 같이 점심 정할 때 편할 것 같아요.',
      author: '강남직장인',
    ),
    AdminInquiry(
      id: 'Q-0511-119',
      type: '기타',
      status: AdminInquiryStatus.completed,
      elapsed: '어제',
      title: '개인정보 처리 관련 문의',
      body: '제 위치 정보가 어떻게 저장되고 활용되는지 자세히 알고 싶습니다.',
      author: '익명사용자',
      answer: '위치 정보는 주변 매장 탐색 목적에만 사용되며 별도로 저장하지 않습니다.',
    ),
  ],
);
