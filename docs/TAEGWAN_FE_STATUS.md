# 오태관 FE 구현 현황

마지막 업데이트: 2026-06-08

## 요약

오태관 담당 21개 화면 중 커뮤니티 및 제보 관련 화면(10개) 및 홈 AI 추천 FAB 진입(8-1) 화면은 Flutter 화면으로 구현이 완료되었습니다. 다만 AI 추천 관련 챗봇 화면들(8-2, 8-3, 8-4) 및 절약 리포트 관련 화면(4-1 ~ 4-7)은 아직 미완료 및 미구현 상태입니다.

## 구현 상태 요약

| 번호 | 화면명 | 상태 | 비고 / 진입 경로 |
| --- | --- | --- | --- |
| `3-1` | 동네 제보 커뮤니티 피드 | **구현 완료** | 바텀 탭 탐색 (`lib/features/community/presentation/screens/community_feed_screen.dart`) |
| `3-2` | 제보 등록 | **구현 완료** | 커뮤니티 피드 > 제보하기 (`lib/features/community/presentation/screens/report_create_screen.dart`) |
| `3-3` | 제보 완료 | **구현 완료** | 제보 등록 완료 후 이동 (`lib/features/community/presentation/screens/report_complete_screen.dart`) |
| `3-4` | 내 제보 관리 | **구현 완료** | 마이페이지 > 내 제보 내역 (`lib/features/community/presentation/screens/my_reports_screen.dart`) |
| `3-5` | 제보 상세 / 검토 상태 | **구현 완료** | 내 제보 관리 > 카드 클릭 (`lib/features/community/presentation/screens/report_detail_screen.dart`) |
| `3-6` | 커뮤니티 게시글 상세 | **구현 완료** | 커뮤니티 피드 > 게시글 클릭 (`lib/features/community/presentation/screens/community_post_detail_screen.dart`) |
| `3-A` | 내 제보 · 전체 | **구현 완료** | 내 제보 관리 내 '전체' 탭 (`lib/features/community/presentation/screens/my_reports_screen.dart`) |
| `3-B` | 내 제보 · 검토 중 | **구현 완료** | 내 제보 관리 내 '검토 중' 탭 (`lib/features/community/presentation/screens/my_reports_screen.dart`) |
| `3-C` | 내 제보 · 승인 완료 | **구현 완료** | 내 제보 관리 내 '승인 완료' 탭 (`lib/features/community/presentation/screens/my_reports_screen.dart`) |
| `3-D` | 내 제보 상세 | **구현 완료** | 내 제보 목록 > 제보 카드 클릭 (`lib/features/community/presentation/screens/report_detail_screen.dart`) |
| `4-1` | 절약 리포트 대시보드 | **미구현** | 바텀 탭 리포트 클릭 시 안내 스낵바 노출 (추후 작업 예정) |
| `4-2` | 절약 상세 내역 | **미구현** | 대시보드 상세 |
| `4-3` | 오늘의 픽 · 날씨 추천 | **미구현** | 홈 화면 오늘의 픽 카드 연동 예정 |
| `4-4` | 최적 루트 추천 | **미구현** | 리포트 / 추천 흐름 내 |
| `4-5` | 찜한 매장 | **미구현** | 마이페이지 > 찜한 매장 |
| `4-6` | 알림 | **미구현** | 알림 아이콘 클릭 시 이동 예정 |
| `4-7` | 절약 목표 설정 | **미구현** | 리포트 > 목표 설정 |
| `8-1` | 홈 · AI 추천 FAB 진입 | **구현 완료** | 홈 화면 우측 하단 floating AI 추천 버튼 (피그마 시안 기준 우측 하단 배치 완료) |
| `8-2` | 챗봇 첫 화면 · 추천 질문 | **미완료 (작업 중)** | AI 추천 버튼 클릭 시 진입 (`lib/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart`) |
| `8-3` | 대화 · 조건 분석 | **미완료** | 챗봇 대화 진행 중 조건 분석 화면 (UI/로직 미반영) |
| `8-4` | 루트 추천 응답 | **미완료** | 챗봇 최종 추천 결과 및 루트 안내 화면 (UI/로직 미반영) |

## 실제 기능 연결 상태

- **커뮤니티 및 제보 (3-1 ~ 3-D)**:
  - `MyReportsScreen`에서 필터별 탭 기능(전체, 검토 중, 승인 완료, 보완 요청, 반려) 및 상태별 분기가 정상 작동하며, 각 탭 내 카드를 통해 상세 조회(`ReportDetailScreen`) 및 보완 요청 시 제보 수정(`ReportCreateScreen`) 진입이 가능합니다.
- **절약 리포트 (4-1 ~ 4-7)**:
  - 현재 바텀 네비게이션바의 '리포트' 탭 클릭 시, 다음 우선순위에서 작업할 수 있도록 안내 스낵바를 표시하는 임시 코드가 적용되어 있습니다.
- **AI 추천 (8-1 ~ 8-4)**:
  - 홈 화면의 AI 추천 버튼(8-1) 및 챗봇 첫 화면의 추천 질문 UI(8-2)는 `ai_recommend_chat_screen.dart` 파일에 기본 레이아웃이 구현되어 있으나, 피그마 시안 기준 완전한 UI 적용 및 백엔드 API 연동이 완료되지 않은 미완료 상태입니다.
  - 대화 및 조건 분석(8-3)과 루트 추천 응답(8-4)은 화면 내 메시지 송수신 및 AI 추천 결과 UI가 추가로 구현되어야 합니다.

## 검증 명령

```bash
dart analyze lib test
flutter test
```

## 남은 백엔드 및 기능 연동 지점

- 절약 리포트 대시보드 및 상세 데이터 연동
- 오늘의 픽(날씨 및 추천 매장) API 연동
- 챗봇 질문 전송 및 AI 추천 결과(매장 및 추천 루트) 수신 API 연동
- 내 제보 상태(검토 중, 승인 완료, 보완 요청 등) 실시간 연동
