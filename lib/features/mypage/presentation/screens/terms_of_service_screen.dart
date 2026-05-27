import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/document_page.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentPage(
      title: '5-K 서비스 이용약관',
      updatedAt: '2026.05.27',
      sections: [
        DocumentSection(
          title: '1. 서비스 목적',
          body: '얼마고?는 착한가격업소 정보와 사용자 제보 가격 정보를 탐색하고 비교할 수 있도록 돕는 서비스입니다.',
        ),
        DocumentSection(
          title: '2. 사용자 제보',
          body:
              '사용자는 사실에 기반한 가격, 메뉴, 위치 정보를 제보해야 하며, 부정확한 정보는 관리자 검토 과정에서 제한될 수 있습니다.',
        ),
        DocumentSection(
          title: '3. 리뷰와 방문 인증',
          body: '리뷰와 방문 인증은 서비스 품질 향상을 위해 사용되며, 허위 정보나 부적절한 표현은 숨김 처리될 수 있습니다.',
        ),
        DocumentSection(
          title: '4. 데이터 책임',
          body: '공공데이터와 외부 지도 정보는 제공 기관의 갱신 주기에 따라 실제 현장 정보와 차이가 있을 수 있습니다.',
        ),
      ],
    );
  }
}
