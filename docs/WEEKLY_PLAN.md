# 얼마에요(HowMuch) 주차별 개발 계획

> 목표: **8월 말 개강(8/31)까지 앱 기능 90% 완성**
> 기준일: 2026-07-21 (화) / 작성: 민서(PM)
> 진행 방식: 지환님(BE) API 선행 완성 → 단톡 공지 → 담당 FE가 다음 주에 연동

---

## ✅ 2주차 (7/21~7/27) — 방문·제보 마무리 [공지 완료]

| 담당 | 과제 |
|---|---|
| 박지환 (BE) | GET /api/visits 개발 (응답: 방문 일시, 매장명, 절약 금액). 여유 되면 방문 인증 POST도 |
| 김다나 (FE) | 지환님 API 완성 공지 후 visit_history_screen.dart 연동. 총 방문 횟수·월별 절약 금액 동적 계산 |
| 오태관 (FE) | report_detail_v2_screen.dart 연동 (UserReportStatus 활용). 상태별 스텝퍼, 반려 시 rejectReason 경고창, 매장 정보 카드 실데이터 |
| 민서 (PM) | review_list_screen.dart 매장별 평점·리뷰 수 동적 계산 + GET /api/review/my (BE 지원) |

## 3주차 (7/28~8/3) — 절약 코어 (앱 정체성 기능)

| 담당 | 과제 |
|---|---|
| 박지환 (BE) | GET /api/savings/history + /api/savings/stats (visits 데이터 기반 월별 집계) |
| 김다나 (FE) | 절약 대시보드(savings_report_dashboard) + 절약 상세(savings_detail) 화면 연동 |
| 오태관 (FE) | 내 리뷰 목록 화면(my_reviews_screen) 연동 |
| 민서 (PM) | 찜하기 API (/api/favorites CRUD) + 절약 목표 설정 API |

## 4주차 (8/4~8/10) — 커뮤니티·찜

| 담당 | 과제 |
|---|---|
| 박지환 (BE) | GET /api/community/feed + 피드 상세 |
| 김다나 (FE) | community_feed + 게시글 상세(community_post_detail) 연동 |
| 오태관 (FE) | 찜한 가게(favorite_stores) 연동 + 절약 목표 설정 화면 연동 |
| 민서 (PM) | 어드민 API (/api/admin/reports + /{id}/approve + /{id}/reject, rejectReason 저장) |

## 5주차 (8/11~8/17) — 어드민·알림·계정

| 담당 | 과제 |
|---|---|
| 박지환 (BE) | GET /api/notifications + 읽음 처리 |
| 김다나 (FE) | 알림 화면(notifications) + 알림 설정 연동 |
| 오태관 (FE) | 어드민 제보 처리 화면(admin_report_review) 연동 — 승인/반려 + 반려 사유 입력 |
| 민서 (PM) | 문의 API (/api/inquiry + /api/admin/inquiries) + 회원 탈퇴 (DELETE /api/user) |

## 6주차 (8/18~8/24) — 추천·통합 안정화

| 담당 | 과제 |
|---|---|
| 박지환 (BE) | 오늘의 픽 추천 (관심 카테고리 + 동네 기반 룰, 간단 버전) |
| 김다나 (FE) | 오늘의 픽(todays_pick) 연동 + 가격 알림 구독 |
| 오태관 (FE) | 전체 화면 폴리싱 + 버그픽스 (최적 동선은 간이 구현 or 제외 → 90%의 -10%) |
| 민서 (PM) | 통합 테스트, Firestore 보안 룰, 공공데이터 스냅샷 자동화, Blaze(종량제) 전환 판단 |

## 7주차 (8/25~8/31) — QA·출시 버퍼

| 담당 | 과제 |
|---|---|
| 전원 | 시나리오 QA (로그인→지도→제보→방문→리뷰→절약), 밀린 작업 흡수 |
| 민서 (PM) | 스토어 등록 준비 (스크린샷/설명문/개인정보처리방침), 성능 점검 (지도 마커, 캐시) |

---

## 운영 원칙

1. **리듬 고정**: 지환님 API 완성 → 단톡 공지 → 담당 FE가 다음 주 초에 연동
2. BE가 밀리면 해당 주 FE는 폴리싱/버그픽스로 전환
3. **매주 일요일** 주차 목표 달성률 단톡 공유, 미달 시 다음 주 범위 조정
4. 8월 마지막 주는 무조건 버퍼 — 밀린 작업 흡수용

## 인프라 메모 (완료된 항목)

- 세션 토큰 인증(HMAC), ApiClient 일원화, 리뷰 API, /api/stores 캐시 구조는 **완료** (2026-07-21)
- Render SESSION_SECRET은 render.yaml `generateValue`로 자동 주입
- Firestore 일일 읽기: 캐시 구조로 하루 ~1.1만 1회 + 소량 (5만 한도 내 여유)