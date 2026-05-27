import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_card.dart';
import 'package:howmuch/shared/widgets/howmuch_scaffold.dart';
import 'package:howmuch/shared/widgets/howmuch_section.dart';

class PublicDataSourceScreen extends StatelessWidget {
  const PublicDataSourceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HowmuchScaffold(
      title: '5-D 공공데이터 출처',
      subtitle: '서비스에서 사용하는 착한가격업소 데이터와 사용자 제보 데이터의 기준을 안내합니다.',
      child: Column(
        children: const [
          _SourceCard(
            icon: Icons.account_balance,
            title: '행정안전부 착한가격업소',
            description: '지자체가 지정한 착한가격업소명, 주소, 업종, 대표 메뉴 정보를 기반으로 합니다.',
            updateCycle: '공공데이터 갱신 주기에 맞춰 반영 예정',
          ),
          SizedBox(height: 12),
          _SourceCard(
            icon: Icons.map,
            title: '위치/지도 데이터',
            description: '지도 API 연동 후 좌표, 거리, 길찾기 정보를 외부 지도 서비스와 연결합니다.',
            updateCycle: '네이버지도 또는 카카오지도 API 연동 예정',
          ),
          SizedBox(height: 12),
          _SourceCard(
            icon: Icons.rate_review,
            title: '사용자 제보 데이터',
            description: '가격표, 메뉴, 방문 인증 등 사용자가 제출한 정보는 관리자 검토 후 노출합니다.',
            updateCycle: '관리자 승인 이후 반영',
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.updateCycle,
  });

  final IconData icon;
  final String title;
  final String description;
  final String updateCycle;

  @override
  Widget build(BuildContext context) {
    return HowmuchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title, trailing: Icon(icon)),
          const SizedBox(height: 8),
          Text(description),
          const SizedBox(height: 10),
          Chip(label: Text(updateCycle)),
        ],
      ),
    );
  }
}
