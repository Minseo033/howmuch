# 얼마에요 프로젝트 현황 (핸드오프 문서)

> 새 세션/팀원이 이 파일 하나로 상황 파악. 최종 갱신: 2026-08-03 (2차)
> 최신 main: ba5f453 (어드민 웹 페이지 + 어드민 API)
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
- **김다나 (FE)**: ✅ savings 대시보드 + 절약 상세 + 목표 설정 연동 (46f68a8 선별 이식 + API 계약 수정). 대시보드: /api/savings/stats 3구간 + goal + favorites/report 개수 실데이터화, 상세: /api/savings/history 파싱·누적/평균 계산, 목표 설정: GET/POST /api/savings/goal. 목업은 API 실패 시 폴백으로만 표시. **→ 3주차 과제 전원 완료**
- **QA 완료 (8/1~8/3)**: 백엔드 공개/인증 스모크 17건 + 실세션 토큰 인증 API 19건 전부 통과 + Playwright 게스트 E2E (로그인→권한→홈→탭) 통과. 내 리뷰 로그인 필요 상태 라이브 확인. 스크립트: `/tmp/howmuch-qa/` (qa_v6.js 웹 E2E, qa_auth.js 인증 API — 토큰은 인자로 전달, 재사용 가능)

## 5-1. 다음 작업 (우선순위 순)
1. **4주차 과제 (8/4~8/10, WEEKLY_PLAN 참조)** — 지환(BE): GET /api/community/feed + 피드 상세 / 다나(FE): community_feed + community_post_detail 연동 / 태관(FE): favorite_stores 연동 (⚠️ "절약 목표 설정 화면 연동"은 46f68a8에서 이미 완료 → 찜한 가게만 배정) / 민서(PM): 어드민 API + 웹 어드민 페이지 ✅ 구현 완료 (8/3, 배포 대기 — AdminController + web/admin.html, compileJava 통과). **어드민은 앱 내 화면 대신 웹 페이지로 전환 결정 (8/3)**. 라이브 전 필요 3가지: ① Render env에 ADMIN_KEY 등록 (레포가 public이라 코드에 기본값 두지 않음, 미설정 시 전부 403) ② 백엔드 push ③ 웹 재배포. 접속: /admin.html → 어드민 전용 비밀번호 로그인 (앱 카카오 로그인과 무관, X-Admin-Key 헤더 인증, 실패 시 1초 지연으로 브루트포스 완화)
2. **자동 로그인 재구현** — dc43efa(토큰 있으면 스플래시→홈 직행)를 26d8a01에서 revert. 원인: ① ApiClient.isAuthenticated는 로컬 토큰 문자열 존재만 체크 → 168h 만료 토큰으로 홈 진입 시 모든 인증 API 401인데 글로벌 401 핸들러·재로그인 유도가 없음 ② authStateProvider(isLoggedIn) 미복원 → 토큰은 있는데 앱은 게스트 상태로 동작하는 모순. 재구현 시: 스플래시에서 /api/user/profile로 토큰 검증 → 200이면 authState 복원 + 홈, 401이면 clearSession + 로그인 화면
3. **매장 상세 별점 헤더 목업** ("4.6 · 리뷰 128") — storeReviewProvider 데이터로 실제 평균/개수 표시 가능 (백엔드 추가 작업 불필요)
4. **마이페이지 프로필 목업** — 게스트/미로그인 시 "절약왕 민서" 목업 표시됨. 로그인 상태 연동 필요
5. **남은 목업들**: 영업시간, 찜 버튼("추후 개발 예정" 스낵바 → /api/favorites 연결 가능)
6. ~~예상 절약 금액(2,000원) 목업~~ → ✅ 방문 인증 플로우 실데이터화 완료 (8/3~8/4): POST /api/visits + 절약 금액 서버 룰 **v2 참가격 기반** (ReferencePrices.java — 한국소비자원 참가격 근사치 품목 테이블 60여 개, 메뉴 매칭 우선 → 실제 업종 11개 카테고리 평균 폼백. 절약 = 기준가 − 결제가, 하한 0). GET /api/visits/estimate 미리보기 API + 인증 화면 400ms 디바운스 연동 (참가격 기준가 표시). 완료 화면 실제 savedAmount + 이번 달 누적. ⚠️ 참가격 값은 근사치라 주기적 갱신 필요, 삼겹살 등 인분 단위 품목은 오차 가능

## 5-2. 주의사항 (이번 세션에서 겪은 함정)
- **자동 로그인을 토큰 존재 체크만으로 구현 금지** (dc43efa → 11분 만에 26d8a01 revert): isAuthenticated는 만료 여부를 모르고, Riverpod authState도 복원 안 됨. 반드시 서버 검증 + authState 복원 + 401 시 clearSession/로그인 리다이렉트 경로 확보 후 도입
- **Vercel 프로젝트 2개 존재**: `howmuch`(=howmuch-zeta.vercel.app, 진짜 프로덕션)와 `web`(구버전 잔재). `build/web/.vercel` 링크가 web을 가리키면 잘못 배포됨 → 배포 전 `npx vercel projects ls`로 확인, `vercel link --project howmuch` 후 deploy
- **store_detail_screen.dart는 대형 파일(894줄)**: 구조 깨지기 쉬움. replace_in_file로 SEARCH 실패 시 fuzzy match로 엉뚱한 곳이 교철될 수 있음 → 작은 단위로 나누거나 Python 패치 사용 (`/tmp/patch_detail.py` 참고)
- **웹 QA 팁**: Flutter web 텍스트는 시맨틱 활성화(flt-semantics-placeholder 클릭) 후 `document.body.innerText`로 추출. 하단 네비는 시맨틱에 안 잡혀서 좌표 클릭 (390x844 기준 홈 40,812 / 탐색 115 / 제보 195,805 / 리포트 272 / 마이 350)
- **어드민 웹 페이지 (web/admin.html)**: flutter build 시 build/web에 자동 포함 → /admin.html로 서빙 (Vercel rewrite는 실제 파일을 덮지 않음). 인증: 어드민 전용 비밀번호 (X-Admin-Key 헤더 ↔ env ADMIN_KEY, 상수 시간 비교 + 실패 시 1초 지연) — 앱 세션과 무관, sessionStorage에만 보관. ADMIN_KEY 미설정 시 전부 403. 뷰 2개: 제보 관리(/api/admin/reports·approve·reject) + 대시보드(/api/admin/overview·users — 회원 수/매장 수/리뷰·방문·찜 수, 회원 목록 테이블. 매장 수는 인메모리 캐시라 읽기 0, 나머지는 count 집계). 승인 매장의 공식 stores 반영 로직은 미구현 (후속 과제)
- **푸시(재배포)마다 공공데이터 1.1만 읽기 소진 (8/3 사고, 수정 완료)** — 상세는 5-3 참고

## 5-3. 8/3 Firestore 일일 쿼터 소진 사고 기록 (원인·예방·주의사항)

**증상**: 8/3 22시경 어드민 페이지·앱 API 전부 `RESOURCE_EXHAUSTED: Quota exceeded` (무료 플랜 일일 읽기 5만 소진). 리셋은 매일 오후 4시 KST (미 태평양시간 자정).

**원인 (근본)**: 공공데이터 24h 갱신 가드(`lastGovRefreshSuccessMillis`)가 인메모리 변수라 **재시작 시 0으로 초기화** → Render 재배포/재시작 후 10분 뒤 스케줄러가 가드를 무시하고 11,207건 전량 강제 갱신. 당일 푸시 6회(다나 이식·자동로그인·revert·어드민 3건) × 1.1만 ≈ 최대 6.7만 읽기 → 한도 초과. 어드민 페이지 쿼리(수십 건)는 무관이었음.

**수정 (0e519e7)**: 마지막 갱신 시각을 Firestore `meta/govStores` 문서에 저장 → 재시작 후에도 24h 가드 유지 (주기 확인 비용 읽기 1회). 메타 조회 실패 시 전량 갱신 대신 그 주기 건너뜀 (안전한 실패).

**예방·주의사항**:
1. **push = Render 재배포 = 비용** — docs만 바뀐 커밋도 재배포 트리거. 문서 전용 커밋은 모아서 하거나 Render build filter 고려
2. 대량 조회 신규 추가 시 캐시 패턴 필수 (기존 원칙) + 건수 확인은 count 집계 쿼리 사용 (1000건당 읽기 1회)
3. 쿼터 초과 시 앱 전체(리뷰/제보/프로필/방문)도 동시에 실패 — 사용자 안내는 "오후 4시 이후 재시도"
4. 반복 발생하면 Blaze(종량제) 전환 (무료 5만 유지 + 초과분만 과금, 이 규모면 월 몇백 원) — 6주차 과제
5. Firebase 콘솔 → Firestore 사용량 탭에서 일일 읽기 추적 가능

## 6. 알려진 주의사항
- Render 무료 인스턴스는 슬립/휘발성 디스크 (classpath 스냅샷이 유일한 영속 캐시)
- Firestore 쿼터: 유저 데이터(리뷰/제보/프로필/방문)만 읽음. 대량 조회 신규 추가 시 캐시 패턴 필수
- 웹에서 debugPrint는 릴리스 빌드에서 무력 — QA는 Playwright로
- 토큰 절약: 작업 단위로 새 채팅, 이 문서로 상황 인계