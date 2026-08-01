# 얼마에요 프로젝트 현황 (핸드오프 문서)

> 새 세션/팀원이 이 파일 하나로 상황 파악. 최종 갱신: 2026-08-01
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

## 5. 현재 진행 중 / 다음 작업 (3주차: 7/28~8/3)
- **박지환 (BE)**: ✅ 완료·이식 (2556eef) — GET /api/savings/history + /api/savings/stats
- **김다나 (FE)**: ⏳ 미착수 — savings 대시보드 + 절약 상세 화면 연동 (다나 머지는 추후)
- **오태관 (FE)**: ✅ 완료·이식 (2556eef) — my_reviews_screen 연동 + GET /api/review/me
- **민서 (PM)**: ✅ 완료 (4186c0a) — /api/favorites CRUD, /api/savings/goal GET/POST (users/{uid} merge 저장으로 재시작 후에도 유지). GET /api/review/my는 태관의 /api/review/me로 대체
- **인증 필터**: /api/favorites, /api/savings, /api/review/me 경로 등록 완료 (SessionAuthFilter)
- **다음 확인할 것**: Render 배포(2556eef) 완료 후 신규 API 스모크 테스트 + 다나 savings 대시보드 연동 시 /api/savings/goal·stats 사용

## 6. 알려진 주의사항
- Render 무료 인스턴스는 슬립/휘발성 디스크 (classpath 스냅샷이 유일한 영속 캐시)
- Firestore 쿼터: 유저 데이터(리뷰/제보/프로필/방문)만 읽음. 대량 조회 신규 추가 시 캐시 패턴 필수
- 웹에서 debugPrint는 릴리스 빌드에서 무력 — QA는 Playwright로
- 토큰 절약: 작업 단위로 새 채팅, 이 문서로 상황 인계