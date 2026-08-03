# 얼마에요 프로젝트 현황 (핸드오프 문서)

> 새 세션/팀원이 이 파일 하나로 상황 파악. 최종 갱신: 2026-08-03
> 최신 main: c9098d6 (회원가입 절약 목표 + 매장 상세 리뷰 실데이터화)
> 장기 계획은 `docs/WEEKLY_PLAN.md` 참조 (8/31 개강까지 앱 90% 완성 목표)

## 1. 프로젝트 구성
- **앱**: Flutter + Riverpod + go_router (`lib/`), iOS/Android/Web
- **백엔드**: Spring Boot 3 + Firestore (`howmuch_backend/`), Render 배포 → `https://howmuch-backend-1xnu.onrender.com`
- **웹 배포**: Vercel CLI 수동 배포 → `https://howmuch-zeta.vercel.app` (git 연동 자동 배포 아님!)
- **브랜치 전략**: `main` + 개인 브랜치. **팀원 브랜치 통째 머지 금지 — 신규 파일/메서드만 선별 이식** (구버전 공유 파일 롤백 방지)

## 2. 완료된 인프라 (재작업 금지)
- **세션 인증**: 카카오 로그인 → 백엔드 세션 토큰(HMAC-SHA256, 168h) → `Authorization: Bearer` + `SessionAuthFilter`(uid를 `authenticatedUid` attribute로 주입). 프론트는 `lib/core/network/api_client.dart`에서 토큰 저장/복원(SharedPreferences), `jsonHeaders(auth: true)`
- **CORS**: 필터에서 OPTIONS preflight 항상 통과. WebConfig allowedOrigins(*)
- **Firestore 쿼터 보호**: 공공데이터 11,207건은 `howmuch_backend/src/main/resources/stores-snapshot.json` 번들 + 인메모리 캐시. 부팅 로드: 디스크→classpath→Firestore. 갱신 1시간 주기 + 성공 후 24h 가드 (일 읽기 ~1.1만 1회). **콜드스타트 읽기 0 달성 완료**
- **라이브 API**: /api/auth/kakao, /api/stores/all·bounds, /api/review(GET/POST·me), /api/report/store·my, /api/user/profile, /api/ai/chat, /api/visits, /api/public-data/sync, /api/favorites(GET/POST/DELETE), /api/savings/goal(GET/POST)·history·stats
- **리뷰 프론트**: Review 모델 + storeId(매장명) 키 맵 상태, 목록/작성 API 연동 완료
- **웹 SPA**: vercel.json + web/vercel.json (빌드 산출물에 자동 포함) — 하위 경로 새로고침 200

## 3. 최근 버그 수정 (7/23, 커밋 해시 869532a0 기준)
1. 웹 카카오맵이 서울 중심 기본값으로 표시 + 현위치 버튼 미동작 → 맵 객체 비동기 등록 레이스. `home_map_screen.dart` `_initWebMap`에 3초/8초 지연 재시도
2. 마이페이지 "내 제보 상태" 재접속 시 사라짐 → `mypage_screen.dart` ConsumerStatefulWidget 전환 + initState에서 `reportService.fetchMyReports()` 재조회
3. 매번 온보딩 표시 → `splash_screen.dart`에서 SharedPreferences `onboarding_completed` 분기, `kakao_login_service.dart` 로그인 성공 시 플래그 저장
- 주의: geolocator 12.0.0은 `getCurrentPosition(desiredAccuracy:, timeLimit:)` 구형 파라미터가 정상 API (locationSettings 없음)

## 4. 배포 방법
- **백엔드**: `git push origin main` → Render 자동 배포 (자바 빌드 ~5-8분)
- **웹**: `flutter build web --release` → `cd build/web && npx -y vercel@latest deploy --prod --yes` (minseo033 로그인 유지)
- **검증 도구**: `/tmp/howmuch-qa/` Playwright 스크립트 (qa.js, qa2~4.js, probe_geo.js). `node qa.js` 전체 화면 QA, `node probe_geo.js` 지도 위치 검증

## 5. 3주차 완료 내역 (7/28~8/3) — 8/1~8/3 QA·버그픽스·추가 작업 포함
- **박지환 (BE)**: ✅ /api/savings/history + /api/savings/stats (2556eef 이식)
- **오태관 (FE)**: ✅ my_reviews_screen + GET /api/review/me (2556eef) + 캐시 버그 2건 수정 (299630b: 로그인 후 미갱신, 리뷰 작성 후 목록 미반영 — MyReviewsNotifier.invalidate() 패턴)
- **민서 (PM)**: ✅ /api/favorites CRUD + /api/savings/goal GET/POST (4186c0a) + 회원가입 화면 절약 목표 입력 (c9098d6, profile_setup_screen에 선택 필드, submit 시 goal 저장) + 매장 상세 리뷰 섹션 실데이터화 (c9098d6, _StoreReviewSection — storeId=매장명 키로 storeReviewProvider 재사용, 개수/평균/최신 3건/빈 상태)
- **김다나 (FE)**: ⏳ 미착수 — savings 대시보드 + 절약 상세 화면 연동 (유일한 남은 3주차 과제)
- **QA 완료 (8/1~8/3)**: 백엔드 공개/인증 스모크 17건 + 실세션 토큰 인증 API 19건 전부 통과 + Playwright 게스트 E2E (로그인→권한→홈→탭) 통과. 내 리뷰 로그인 필요 상태 라이브 확인. 스크립트: `/tmp/howmuch-qa/` (qa_v6.js 웹 E2E, qa_auth.js 인증 API — 토큰은 인자로 전달, 재사용 가능)

## 5-1. 다음 작업 (우선순위 순)
1. **다나 savings 대시보드 연동** — 백엔드 준비 완료 (/api/savings/goal·history·stats, period=this_month|last_month|this_year, 주차별/월별 차트). 현재 대시보드는 목업(24,500원·2026.05) 표시 중
2. **매장 상세 별점 헤더 목업** ("4.6 · 리뷰 128") — storeReviewProvider 데이터로 실제 평균/개수 표시 가능 (백엔드 추가 작업 불필요)
3. **마이페이지 프로필 목업** — 게스트/미로그인 시 "절약왕 민서" 목업 표시됨. 로그인 상태 연동 필요
4. **남은 목업들**: 예상 절약 금액(2,000원), 영업시간, 찜 버튼("추후 개발 예정" 스낵바 → /api/favorites 연결 가능)

## 5-2. 주의사항 (이번 세션에서 겪은 함정)
- **Vercel 프로젝트 2개 존재**: `howmuch`(=howmuch-zeta.vercel.app, 진짜 프로덕션)와 `web`(구버전 잔재). `build/web/.vercel` 링크가 web을 가리키면 잘못 배포됨 → 배포 전 `npx vercel projects ls`로 확인, `vercel link --project howmuch` 후 deploy
- **store_detail_screen.dart는 대형 파일(894줄)**: 구조 깨지기 쉬움. replace_in_file로 SEARCH 실패 시 fuzzy match로 엉뚱한 곳이 교철될 수 있음 → 작은 단위로 나누거나 Python 패치 사용 (`/tmp/patch_detail.py` 참고)
- **웹 QA 팁**: Flutter web 텍스트는 시맨틱 활성화(flt-semantics-placeholder 클릭) 후 `document.body.innerText`로 추출. 하단 네비는 시맨틱에 안 잡혀서 좌표 클릭 (390x844 기준 홈 40,812 / 탐색 115 / 제보 195,805 / 리포트 272 / 마이 350)

## 6. 알려진 주의사항
- Render 무료 인스턴스는 슬립/휘발성 디스크 (classpath 스냅샷이 유일한 영속 캐시)
- Firestore 쿼터: 유저 데이터(리뷰/제보/프로필/방문)만 읽음. 대량 조회 신규 추가 시 캐시 패턴 필수
- 웹에서 debugPrint는 릴리스 빌드에서 무력 — QA는 Playwright로
- 토큰 절약: 작업 단위로 새 채팅, 이 문서로 상황 인계