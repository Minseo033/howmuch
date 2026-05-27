import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/document_page.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocumentPage(
      title: '5-J 개인정보 처리방침',
      updatedAt: '2026.05.27',
      sections: [
        DocumentSection(
          title: '1. 수집하는 정보',
          body:
              '얼마고?는 로그인 식별 정보, 관심 지역, 알림 설정, 제보 및 리뷰 작성 정보를 서비스 제공 목적으로 수집합니다.',
        ),
        DocumentSection(
          title: '2. 이용 목적',
          body: '수집한 정보는 주변 매장 추천, 가격 알림, 제보 검토 결과 안내, 문의 응대에 사용됩니다.',
        ),
        DocumentSection(
          title: '3. 보관 및 파기',
          body: '회원 탈퇴 또는 목적 달성 시 관련 법령과 내부 정책에 따라 정보를 파기하거나 비식별 처리합니다.',
        ),
        DocumentSection(
          title: '4. 외부 연동',
          body: '지도, 소셜 로그인, 공공데이터 연동 시 필요한 최소 정보만 외부 서비스와 연결합니다.',
        ),
      ],
    );
  }
}
