# 얼마에요 프로젝트 현황 (핸드오프 문서)

> 새 세션/팀원이 이 파일 하나로 상황 파악. 최종 갱신: 2026-08-05
> 최신 main: 3af493f (8/5 지환 4주차 커뮤니티 피드 API 선별 이식 + 보안 수정)
> 8/4 감사 이슈 코드 수정 + 어드민 페이지 개선 + UI 피드백 반영 전부 배포 완료 — 상세는 5-4·5-5 참조
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

## 5-0. 4주차 진행 내역 (8/4~8/10)
- **박지환 (BE)**: ✅ GET /api/community/feed + /api/community/feed/{id} (a919b66 → 3af493f 선별 이식). 신규 CommunityController + FeedResponseDto/FeedDetailResponseDto + FirebaseService getCommunityFeeds/getCommunityFeedDetail. **이식 시 보안 수정 3건**: ① REJECTED 제보 피드·상세 제외 (isFeedVisible — PENDING·APPROVED·레거시만 노출, 지도 isPubliclyVisible과 정책 일관성) ② rejectReason 공개 응답 제거 (내부 심사 코멘트 비공개) ③ createdAt 메모리 정렬 (Firestore 인덱스 불필요 + 레거시 호환). compileJava 통과. **⚠️ 쿼터 주의**: 피드 목록이 호출마다 stores_user 전체 읽기 + 작성자당 users 1회 — 제보 수 증가 시 인메모리 캐시 필요. likes/comments는 백엔드 미구현이라 전부 0 (목업 placeholder, 좋아요·댓글은 후속 과제). **→ 다나(FE) community_feed + community_post_detail 연동 가능**

## 5-1. 다음 작업 (우선순위 순)
1. **4주차 과제 (8/4~8/10, WEEKLY_PLAN 참조)** — 지환(BE): GET /api/community/feed + 피드 상세 / 다나(FE): community_feed + community_post_detail 연동 / 태관(FE): favorite_stores 연동 (⚠️ "절약 목표 설정 화면 연동"은 46f68a8에서 이미 완료 → 찜한 가게만 배정) / 민서(PM): 어드민 API + 웹 어드민 페이지 ✅ 구현 완료 (8/3, 배포 대기 — AdminController + web/admin.html, compileJava 통과). **어드민은 앱 내 화면 대신 웹 페이지로 전환 결정 (8/3)**. 라이브 전 필요 3가지: ① Render env에 ADMIN_KEY 등록 (레포가 public이라 코드에 기본값 두지 않음, 미설정 시 전부 403) ② 백엔드 push ③ 웹 재배포. 접속: /admin.html → 어드민 전용 비밀번호 로그인 (앱 카카오 로그인과 무관, X-Admin-Key 헤더 인증, 실패 시 1초 지연으로 브루트포스 완화)
2. **자동 로그인 재구현** — dc43efa(토큰 있으면 스플래시→홈 직행)를 26d8a01에서 revert. 원인: ① ApiClient.isAuthenticated는 로컬 토큰 문자열 존재만 체크 → 168h 만료 토큰으로 홈 진입 시 모든 인증 API 401인데 글로벌 401 핸들러·재로그인 유도가 없음 ② authStateProvider(isLoggedIn) 미복원 → 토큰은 있는데 앱은 게스트 상태로 동작하는 모순. 재구현 시: 스플래시에서 /api/user/profile로 토큰 검증 → 200이면 authState 복원 + 홈, 401이면 clearSession + 로그인 화면
3. **매장 상세 별점 헤더 목업** ("4.6 · 리뷰 128") — storeReviewProvider 데이터로 실제 평균/개수 표시 가능 (백엔드 추가 작업 불필요)
4. **마이페이지 프로필 목업** — 게스트/미로그인 시 "절약왕 민서" 목업 표시됨. 로그인 상태 연동 필요
5. **남은 목업들**: 영업시간, 찜 버튼("추후 개발 예정" 스낵바 → /api/favorites 연결 가능 — 태관 4주차 과제)
6. ~~오늘의 픽(날씨 추천) 기획~~ → ✅ 5주차 민서(PM) 과제로 변경 (8/4 결정): 기상청 단기예보 연동 → 날씨 기반 추천 룰 + todays_pick 실데이터화 + AI 챗봇 루트 추천(8-3/8-4) + 최적 루트 간이 구현. 기존 6주차 지환(BE)/다나(FE) 오늘의 픽 과제는 6주차 "알림·폴리싱"으로 재배정, 상세는 WEEKLY_PLAN 참조
7. ~~예상 절약 금액(2,000원) 목업~~ → ✅ 방문 인증 플로우 실데이터화 완료 (8/3~8/4): POST /api/visits + 절약 금액 서버 룰 **v2 참가격 기반** (ReferencePrices.java — 한국소비자원 참가격 근사치 품목 테이블 60여 개, 메뉴 매칭 우선 → 실제 업종 11개 카테고리 평균 폼백. 절약 = 기준가 − 결제가, 하한 0). GET /api/visits/estimate 미리보기 API + 인증 화면 400ms 디바운스 연동 (참가격 기준가 표시). 완료 화면 실제 savedAmount + 이번 달 누적. ⚠️ 참가격 값은 근사치라 주기적 갱신 필요, 삼겹살 등 인분 단위 품목은 오차 가능

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

## 5-4. 8/4 전체 코드 감사 결과 (BE/FE/인프라 전수 조사, 미해결 이슈)

### CRITICAL (즉시 조치)
1. **Firebase 개인키 git 히스토리 노출** — `3ad7151`에 firebase-service-account.json 실키 커밋, `8910c86`에서 삭제했으나 히스토리 잔존 (레포 public이라 `git show 3ad7151`으로 누구나 열림). → **Firebase 콘솔에서 키 폐기·재발급 + BFG/filter-repo로 히스토리 purge** (콘솔 작업 필요, 코드 작업만으로 해결 불가)
2. ~~카카오 REST API 키 하드코딩~~ → ✅ **해결 (8/4)** — GeocodingService/KakaoLocalService/GeminiService의 하드코딩 키 제거, `${KAKAO_REST_API_KEY}`·`${GEMINI_API_KEY}` 환경변수 주입으로 전환 (미설정 시 외부 호출 걸지 않고 안전 실패). **Render env에 두 키 등록 필요 + 노출된 구 키는 콘솔에서 재발급 권장** (프론트 profile_setup_screen의 REST 키·home_map의 JS 키는 클라 번들 특성상 도메인 제한으로 보호 — 카카오 콘솔에서 허용 도메인 확인 필요)
3. ~~PENDING·REJECTED 제보가 지도에 공개 노출~~ → ✅ **해결 (8/4)** — `FirebaseService.getStoresInBounds`의 사용자 제보 스트림에 `isPubliclyVisible` 필터 추가: APPROVED 또는 승인제 이전 레거시(status 없음)만 지도 노출, PENDING·REJECTED 제외

### HIGH
4. ~~마이페이지 통째 목업~~ → ✅ **해결 (8/4)** — userProfileProvider 기본값을 게스트('게스트'/0건)로 교체, mypage_screen `_loadProfileSummary()`가 로그인 시 /api/user/profile + /api/savings/stats(this_month) + /api/report/my + /api/favorites로 닉네임/이메일/이번 달 절약액/제보 수/찜 수 실데이터 주입. 남은 목업: 가격 알림 설정·소셜 계정 화면(백엔드 없는 후순위), favorite_stores(태관 4주차 과제)
5. ~~대시보드 폼백 가짜 통계~~ → ✅ **해결 (8/4)** — `_loadFallbackData()` 삭제. 통계 API 전부 실패 시 가짜 숫자 대신 `_buildErrorState()`(아이콘+안내+다시 시도 버튼) 표시. 일부 탭만 실패하면 실패 탭은 0으로 표시 (가짜 금액 아님)
6. **찜 docId에 매장명 사용** — uid+"_"+storeId인데 storeId가 매장 "이름"이라 `/` 등 Firestore 문서 ID 불가 문자 시 찜 실패 → ID 정규화/해시 필요. **⚠️ 태관 4주차 과제(favorite_stores 연동)와 범위가 겹치므로 태관에게 이관 — 이 브랜치에서 수정 금지**
7. ~~SESSION_SECRET 미설정 시 dev 기본값 사용~~ → ✅ **해결 (8/4)** — SessionTokenService 생성자 fail-fast: 미설정/빈값이면 부팅 거부. dev 기본값은 `session.allow-dev-secret=true`(로컬 기본)에서만 허용 + 경고 로그. **운영은 Render env에 SESSION_SECRET(랜덤) + SESSION_ALLOW_DEV_SECRET=false 설정 필요**
8. ~~/api/ai/chat 레이트리밋 없음~~ → ✅ **해결 (8/4)** — SimpleRateLimiter(인메모리 슬라이딩 윈도우) 추가, 유저당 시간당 20회(`AI_CHAT_MAX_PER_HOUR`로 조정) 초과 시 429. message 필수 + 1000자 상한 검증도 함께 추가

### MEDIUM
9. ~~입력 검증 0건~~ → ✅ **해결 (8/4)** — 컨트롤러 수동 검증 추가: 리뷰(content 2000자/필드 길이), 제보(storeName·address 필수+길이), 방문(storeName·price 범위, 상한 1천만), 찜(storeId 길이). Bean Validation 의존성은 이미 있으나 수동 검증으로 처리 (레이트리밋은 #8 참조)
10. ~~요청 스레드 blocking + Gemini 타임아웃 없음~~ → ⚠️ **부분 해결 (8/4)** — Gemini 호출에 connect/read 타임아웃 10초(`GEMINI_TIMEOUT_MS`) 적용. Firestore blocking `.get()`은 현 구조상 유지 (스레드 고갈 리스크는 타임아웃으로 완화, 비동기 전환은 후속 과제)
11. ~~예외 메시지(e.getMessage()) 클라이언트 반환~~ → ✅ **해결 (8/4)** — 전 컨트롤러(Review/Report/Visit/Favorites/User/Admin/Auth/Gemini)의 500 응답에서 날부 에러 상세 제거, 일반 안내 문구로 교체 (상세는 서버 로그에만)

### 확인된 안전 항목 (문제없음)
- 카카오 토큰: 백엔드가 카카오 /v2/user/me로 실제 검증 (클린트 uid 신뢰 안 함)
- uid는 세션 attribute에서만 주입 (IDOR 스푸핑 방지됨)

### 8/4 어드민 페이지 대폭 개선 (compileJava + node 문법 검증 통과)
- **신규 백엔드 API** (전부 X-Admin-Key 인증, ADMIN_KEY 미설정 시 403):
  - `GET  /api/admin/users/{uid}/activity` : 회원 활동 요약 (제보/리뷰/방문/찜 개수, count 집계 쿼리)
  - `DELETE /api/admin/users/{uid}` : 회원 강제 탈퇴 — users 문서 + 제보/리뷰/방문/찜 전부 삭제 (삭제 건수 반환)
  - `GET  /api/admin/reviews` : 전체 리뷰 목록 (최신순, 매장명/작성자명/별점/내용)
  - `DELETE /api/admin/reviews/{id}` : 리뷰 삭제 (404 = 리뷰 없음)
- **web/admin.html 전면 개편**: 다크 사이드바 + 그라데이션 로그인 오버레이 + 4개 뷰
  - 대시보드: 6개 통계 카드(컬러 glow) + 최근 제보 5건 테이블
  - 제보 관리: 상태 탭(대기/승인/반려/전체 + 건수) + 사이드바 대기 pill 배지
  - 리뷰 관리: 별점 표시 + 내용 미리보기 + 삭제(확인 모달)
  - 회원 관리: 아바타(이니셜+컬러) + 닉네임/이메일/지역 검색 + 상세(활동 모달) + 강제 탈퇴(경고 모달)
  - 공통: 토스트, 모달(ESC/배경 클릭 닫기), 로딩/빈/에러/쿼터초과 상태 화면, 반응형(모바일 사이드바→상단 바)
  - JS는 단일 IIFE로 통합 (여러 `<script>` 블록으로 나누면 스코프 깨짐 — node new Function으로 검증)
- FirebaseService에 deleteUser/deleteWhere/getUserActivity/countWhere/getAllReviews/deleteReview 추가

## 5-5. 8/5 세션 종료 시점 상태 요약 (핸드오프)

**배포된 최신 상태 (2026-08-04 기준, 라이브 반영 완료)**
- **백엔드**: 8/4 감사 이슈 코드 수정 + 어드민 관리 API(회원 활동/강제 탈퇴/리뷰 목록·삭제) push 완료 → Render 자동 배포. 라이브 스모크 /api/stores/all 200, /api/user/profile(무토큰) 401 확인. Render env 4개(SESSION_SECRET·SESSION_ALLOW_DEV_SECRET=false·KAKAO_REST_API_KEY·GEMINI_API_KEY) 등록 완료.
- **웹**: 어드민 페이지 전면 개편 + 피드백(이모지 제거·로고 교체·얼마고?·모바일 레이아웃) 반영 후 Vercel 재배포 완료 → https://howmuch-zeta.vercel.app/admin.html (로고 images/app_logo.png 200 확인).
- **커밋**: 8/4 감사 수정(d3a8fe3) → 어드민 개선(7c4d893) → UI 피드백(099a768) → 문서 재배정(314260e) 순으로 main push 완료.

**미완료/다음 세션에서 이어갈 것**
- 찜 연동(매장 상세 찜 버튼 + favorite_stores 화면 + docId 정규화 #6) = **태관 4주차 과제** — 코드 수정 금지, 이 브랜치에서 건드리지 않음
- 자동 로그인 재구현 = **태관 5주차 과제** — 구현 방법(서버 검증 + authState 복원 + 401 시 clearSession)만 5-1·5-2에 기록됨
- 오늘의 픽(기상청 날씨 연동 + 추천 룰 + 루트) = **민서 5주차 과제**로 재배정 완료 (8/4)
- Firebase 노출 키 폐기·재발급 + git 히스토리 purge(감사 #1) = 콘솔 작업, 미완료
- 카카오/Gemini 노출 구 키 재발급 = 권장, 미완료 (Render env는 기존 키로 등록돼 동작은 함)

**이번 세션에서 사용자에게 확인받은 결정**
- 찜 기능이 안 되는 건 버그가 아니라 프론트 연동 미구현 상태 — 태관 4주차 과제로 유지 결정
- 오늘의 픽은 원래 기획에 있었으나 6주차 간단 버전엔 기상청 연동이 빠져 있었음 → 민서 5주차로 이관 확정

### 8/4 코드 수정 내역 (compileJava + flutter analyze 통과)
- **백엔드**: FirebaseService(isPubliclyVisible 필터), GeocodingService·KakaoLocalService·GeminiService(env 키 주입), SessionTokenService(fail-fast), SimpleRateLimiter(신규), AiController(레이트리밋+검증), 7개 컨트롤러(에러 메시지 일반화 + 입력 길이 검증), application.properties(신규 env 키 등록)
- **프론트**: mypage_state.dart(목업 제거), mypage_screen.dart(_loadProfileSummary 실데이터 로드), savings_report_dashboard_screen.dart(폼백 삭제 + 에러/재시도 UI)
- **라이브 반영 필요**: Render env에 KAKAO_REST_API_KEY, GEMINI_API_KEY, SESSION_SECRET(+SESSION_ALLOW_DEV_SECRET=false) 등록 후 백엔드 push, 웹 재배포 (미등록 시 제보 주소 좌표 변환·AI 채팅이 안전 실패 모드로 동작)

## 6. 알려진 주의사항
- Render 무료 인스턴스는 슬립/휘발성 디스크 (classpath 스냅샷이 유일한 영속 캐시)
- Firestore 쿼터: 유저 데이터(리뷰/제보/프로필/방문)만 읽음. 대량 조회 신규 추가 시 캐시 패턴 필수
- 웹에서 debugPrint는 릴리스 빌드에서 무력 — QA는 Playwright로
- 토큰 절약: 작업 단위로 새 채팅, 이 문서로 상황 인계