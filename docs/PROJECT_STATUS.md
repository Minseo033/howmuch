# 얼마에요 프로젝트 현황 (핸드오프 문서)

> 새 세션/팀원이 이 파일 하나로 상황 파악. 최종 갱신: 2026-08-07
> 최신 main: 97088a4 (8/7 **기상청 키 인코딩 수정으로 오늘의 픽 날씨 라이브 정상화** + 미사용 코드 정리 + 어드민 모드 제거 + README 개편). **전부 push 완료 → Render 자동 배포, 라이브 검증 완료 (weatherAvailable:true)**
> 8/7 **오늘의 픽 추천 로직 신빙성 점검·수정 완료** — 상세는 5-11 참조 (코드 수정, 미배포)
> ⚠️ 웹 Vercel 재배포 미실시 (라이브 웹은 어드민 토글 있는 구버전) — 재배포 방법은 5-10 참조
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
- **박지환 (BE)**: ✅ GET /api/community/feed + /api/community/feed/{id} (a919b66 → 3af493f 선별 이식, e28c5ef push → Render 배포 완료). 신규 CommunityController + FeedResponseDto/FeedDetailResponseDto + FirebaseService getCommunityFeeds/getCommunityFeedDetail. **이식 시 보안 수정 3건**: ① REJECTED 제보 피드·상세 제외 (isFeedVisible — PENDING·APPROVED·레거시만 노출, 지도 isPubliclyVisible과 정책 일관성) ② rejectReason 공개 응답 제거 (내부 심사 코멘트 비공개) ③ createdAt 메모리 정렬 (Firestore 인덱스 불필요 + 레거시 호환). compileJava 통과. **라이브 검증 완료 (8/5)**: /api/community/feed 200 (11건, PENDING·APPROVED만, REJECTED 없음), /feed/{id} 200 (rejectReason 없음 확인), 없는 id 404. **⚠️ 쿼터 주의**: 피드 목록이 호출마다 stores_user 전체 읽기 + 작성자당 users 1회 — 제보 수 증가 시 인메모리 캐시 필요. likes/comments는 백엔드 미구현이라 전부 0 (목업 placeholder, 좋아요·댓글은 후속 과제). **→ 다나(FE) community_feed + community_post_detail 연동 가능**
- **CORS 수정 (4bec04b, 8/5 배포 완료)**: SessionAuthFilter가 DispatcherServlet 이전에 401을 직접 반환 → addCorsMappings(MVC 레벨)가 적용 안 돼 401에 Access-Control-Allow-Origin 누락, 브라우저가 401을 CORS 에러로 오인 (웹에서 인증 API 전부 "CORS 실패"로 표시되던 문제). WebConfig에 HIGHEST_PRECEDENCE CorsFilter 빈 추가로 401 포함 모든 응답에 헤더 보장. **이제 프론트가 401을 정상 감지 가능** (자동 로그인 재구현의 전제 조건 해소). 라이브 검증: 401 응답에 allow-origin 헤더 확인, QA에서 CORS 에러 6건 소멸.
- **웹 E2E QA 11/11 통과 (8/5)**: qa_v6.js 개선 — ① 하단 네비를 좌표 클릭 → 시맨틱 노드 JS 직접 클릭(y>780 필터)으로 교체 (마이페이지처럼 콘텐츠가 네비 영역과 겹치는 화면에서 좌표 클릭이 엉뚱한 항목(알림 설정)을 누르던 문제 해소, 좌표는 폼백으로 유지) ② 내 리뷰·제보 작성 같은 전체 화면(하단 네비 없음) 진입 후 Back/브라우저 뒤로가기로 복귀하는 단계 추가 ③ 09_제보화면 검증을 '가성비 매장 제보'/'기본 정보' 텍스트로 강화 (기존 t.length>10은 갇힌 화면에서도 통과하는 허술한 검사였음)
- **김다나 (FE)**: ✅ community_feed + community_post_detail 연동 (ec56278 → bfb3b4f 선별 이식, PR #3은 머지하지 않고 닫기). GET /api/community/feed + /feed/{id} 연동, 상세는 ?id= 쿼리 파라미터 라우팅. **pubspec.lock 구버전 롤백 5건(characters·matcher·material_color_utilities·meta·test_api 다운그레이드)은 이식 제외** — 브랜치 전략의 "구버전 공유 파일 롤백 방지" 사례. **이식 시 수정 3건**: ① 폼백 목업 제거 (PM 결정, 8/4 감사 #5와 일관 — API 실패 시 가짜 글 3건 대신 '불러오지 못했어요 + 다시 시도' 에러 UI, 피드·상세 양쪽) ② 지역 필터 버그 수정 (역삼동/합정동 정확 일치 → 실데이터 location은 '구로구' 등이라 빈 화면 되던 문제, 일치 항목 없으면 전체 표시로 완화) ③ 빈 상태 '아직 제보가 없어요' 추가. flutter analyze 57 이슈(main과 동일, 신규 0) + build web 성공 + Vercel 배포(howmuch-zeta). **라이브 검증 (8/6)**: /community에서 실데이터 13건 표시 확인 (상태 배지 '검토 중'/'승인 완료' 정상, QA 11/11 통과). ⚠️ 댓글 섹션은 목업 2건 유지 (댓글 백엔드 미구현 — 카드의 '댓글 0'과 목록 2건이 불일치하는 상태, 후속 과제). likes도 백엔드 미구현이라 전부 0
- **오태관 (FE)**: ✅ 찜 연동 (9110c08 → 3e6a220 cherry-pick 이식, 8/7 — 충돌 없음, 프론트 3개 파일만 변경). ① favorite_stores 화면 /api/favorites 실데이터화 (하드코딩 목업 3건 제거, 매장명 검색 추가, 로딩/에러-재시도/빈 상태 UI) ② 매장 상세 하트 버튼 찜 추가/해제 연동 ('추후 개발 예정' 스낵바 제거, 낙관적 업데이트 + 실패 롤백) ③ 찜 수 마이페이지 userProfileProvider 낙관적 동기화. 카테고리 필터 칩은 제거됨 (favorites 응답이 storeId·storeName·createdAt뿐이라 카테고리 데이터 없음). flutter analyze error 0·신규 이슈 0 (57개 main과 동일) + build web 성공. ⚠️ 후속 확인 3건: ① 감사 #6 docId 정규화 → **✅ 8/7 해결 (5-7 참조)** ② 게스트가 하트 누륾면 401 실패 스낵바만 표시 (로그인 유도 없음 — 5주차 태관 자동 로그인 과제와 함께 개선 예정, 보류) ③ 찜 카드에 카테고리/메뉴/가격 없음 → **✅ 8/7 해결 (5-7 참조)**. **→ 4주차 과제 전원 완료**

## 5-0-1. 5주차 민서(PM) 과제 완료 (8/7, 0e480da)

**구현 완료**:
1. **문의 API (BE)**: POST /api/inquiry (제목/내용/카테고리 필수 검증, 100/2000자 상한), GET /api/inquiry/my (내 문의 목록 최신순), GET /api/admin/inquiries (어드민 전체 조회). Firestore inquiries 컬렉션 신규. InquiryController + InquiryRequest DTO + FirebaseService createInquiry/getMyInquiries/getAllInquiries.
2. **회원 탈퇴 (BE)**: DELETE /api/user (세션 인증 본인 계정만, users + 제보/리뷰/방문/찜 전부 삭제). UserController에 추가, FirebaseService.deleteUser 재사용.
3. **오늘의 픽 (BE+FE)**: GET /api/recommendation/todays-pick (기상청 단기예보 getVilageFcst → 날씨/기온 → 날씨 기반 추천 룰(비/눈=따뜻한 국물, 맑음/더움=시원한 메뉴) → 공공데이터 인메모리 캐시에서 매장 선별, Firestore 읽기 0). WeatherService + RecommendationController + FirebaseService getTodaysPicks. 프론트 todays_pick_screen 실데이터화 (날씨 카드 실데이터, API 로딩/에러/재시도).
4. **AI 루트 추천 (BE+FE)**: GET /api/recommendation/route (오늘의 픽 매장 목록을 Gemini에 전달해 최적 동선 추천). GeminiService.getRouteRecommendation + RecommendationController.getRoute. 프론트 optimal_route_screen 실데이터화 (AI 추천 이유 표시, 총 비용/거리 계산).
5. **문의/탈퇴 화면 연동 (FE)**: inquiry_screen 문의 본고하기 버튼 실제 API 호출 (inquiry_service), withdrawal_screen 회원 탈퇴 실제 API 호출 (DELETE /api/user) + 로컬 세션 종료.

**배포 전 필요사항**: Render env에 WEATHER_API_KEY 등록 (공공데이터포털 기상청 단기예보 API 키, 미설정 시 오늘의 픽 날씨는 안전 실패). 기존 키(SESSION_SECRET/KAKAO/GEMINI/ADMIN_KEY)는 그대로.

**다음 세션에서 이어갈 것 (우선순위)**:
1. **배포**: WEATHER_API_KEY 등록 후 백엔드 push → Render 자동 배포, 웹 `flutter build web --release` → Vercel 재배포
2. **자동 로그인 재구현** (태관 5주차): 스플래시 토큰 → /api/user/profile 검증 → 200: authState 복원+홈 / 401: clearSession+로그인. CORS 401 수정(4bec04b)으로 전제조건 해소됨.
3. **알림 API** (지환 5주차): GET /api/notifications + POST /api/notifications/{id}/read. Firestore notifications 컬렉션 신규 (userId/title/body/type/isRead/createdAt).
4. **알림 화면** (다나 5주차): 알림 화면 + 알림 설정 연동.
5. **댓글·좋아요 백엔드** (후속): 피드 카드 '댓글 0' vs 목업 댓글 2건 불일치 해소.
6. **피드 API 쿼터 개선**: 호출마다 stores_user 전체 읽기 → 인메모리 캐시 필요.
7. **공개 GET API 레이트리밋**: 현재 AiController만 적용 — 전체 공개 API로 확대.
8. **Firebase 키 폐기·재발급 + git 히스토리 purge** (감사 #1, 콘솔 작업).
9. **카카오/Gemini 노출 구 키 재발급** (권장).
10. **6주차 과제** (8/18~8/24): 알림 발송 로직(가격 변동 제보 시 찜 구독자 알림), 오늘의 픽·루트 화면 폴리싱, 전체 화면 폴리싱 + 버그픽스, 통합 테스트, Firestore 보안 룰, Blaze 전환 판단.

**5주차 세션에서 겪은 환경 문제**:
- replace_in_file이 대형 파일에서 엉뚱한 내용으로 덮어쓰는 사고 발생 (FirebaseService/GeminiService/UserController/AdminController가 서로 내용이 뒤바뀜) → git checkout으로 복원 후 재작성으로 해결. **교훈: 편집 후 `git diff`로 의도한 변경만 들어갔는지 반드시 확인**
- 디스크 공간 부족 (ENOSPC)으로 write_to_file 실패 → build/.dart_tool/.gradle 정리로 해결
- Python 스크립트로 파일 생성 시 터미널 타임아웃 주의 — 짧은 명령으로 분리 실행

## 5-1. 다음 작업 (우선순위 순)
1. **4주차 과제 (8/4~8/10, WEEKLY_PLAN 참조)** — 지환(BE): GET /api/community/feed + 피드 상세 / 다나(FE): community_feed + community_post_detail 연동 / 태관(FE): favorite_stores 연동 (⚠️ "절약 목표 설정 화면 연동"은 46f68a8에서 이미 완료 → 찜한 가게만 배정) / 민서(PM): 어드민 API + 웹 어드민 페이지 ✅ 구현 완료 (8/3, 배포 대기 — AdminController + web/admin.html, compileJava 통과). **어드민은 앱 내 화면 대신 웹 페이지로 전환 결정 (8/3)**. 라이브 전 필요 3가지: ① Render env에 ADMIN_KEY 등록 (레포가 public이라 코드에 기본값 두지 않음, 미설정 시 전부 403) ② 백엔드 push ③ 웹 재배포. 접속: /admin.html → 어드민 전용 비밀번호 로그인 (앱 카카오 로그인과 무관, X-Admin-Key 헤더 인증, 실패 시 1초 지연으로 브루트포스 완화)
2. **자동 로그인 재구현** — dc43efa(토큰 있으면 스플래시→홈 직행)를 26d8a01에서 revert. 원인: ① ApiClient.isAuthenticated는 로컬 토큰 문자열 존재만 체크 → 168h 만료 토큰으로 홈 진입 시 모든 인증 API 401인데 글로벌 401 핸들러·재로그인 유도가 없음 ② authStateProvider(isLoggedIn) 미복원 → 토큰은 있는데 앱은 게스트 상태로 동작하는 모순. 재구현 시: 스플래시에서 /api/user/profile로 토큰 검증 → 200이면 authState 복원 + 홈, 401이면 clearSession + 로그인 화면
3. **매장 상세 별점 헤더 목업** ("4.6 · 리뷰 128") — storeReviewProvider 데이터로 실제 평균/개수 표시 가능 (백엔드 추가 작업 불필요)
4. **마이페이지 프로필 목업** — 게스트/미로그인 시 "절약왕 민서" 목업 표시됨. 로그인 상태 연동 필요
5. **남은 목업들**: 영업시간. ~~찜 버튼~~ → ✅ 8/7 태관 찜 연동 완료 (3e6a220)
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
6. ~~찜 docId에 매장명 사용~~ → ✅ **해결 (8/7)** — FirebaseService favoriteDocId에 sanitizeForDocId 이스케이프 추가 ('_'→'__', '/'→'_s', 단사라 충돌 없음). 매장명에 '/' 있어도 찜 가능. removeFavorite는 구 형식 문서도 함께 삭제해 기존 데이터 호환. 상세는 5-7
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

## 5-6. 8/6~8/7 세션 종료 시점 상태 요약 (핸드오프)

**배포된 최신 상태 (2026-08-06 기준, 전부 라이브 반영 완료)**
- **백엔드 (Render)**: 지환 4주차 커뮤니티 피드 API (GET /api/community/feed + /feed/{id}) + CORS 401 수정(4bec04b) 배포됨. 라이브 검증: feed 200 (PENDING·APPROVED만, REJECTED 제외), 401 응답에 CORS 헤더 확인.
- **웹 (Vercel, howmuch-zeta)**: 다나 4주차 FE 연동(bfb3b4f) 배포됨. /community에서 실데이터 13건 표시 확인 (8/6). QA 11/11 통과.
- **PR #3 (다나)**: 머지 없이 선별 이식 후 닫기 완료 (8/7).

**8/5~8/6 세션에서 한 일 (커밋 순)**
1. `3af493f` 지환 BE 피드 API 선별 이식 + 보안 수정 3건 (REJECTED 제외 isFeedVisible, rejectReason 비공개, createdAt 메모리 정렬)
2. `4bec04b` CORS 401 수정 — WebConfig에 HIGHEST_PRECEDENCE CorsFilter 빈 (SessionAuthFilter의 401에 CORS 헤더 누락되던 문제, 웹에서 인증 API가 "CORS 에러"로 표시되던 것 해소. **자동 로그인 재구현의 401 감지 전제조건 해소됨**)
3. qa_v6.js 개선 — 하단 네비를 시맨틱 노드 JS 직접 클릭(y>780 필터)으로 교체 + 전체 화면(내 리뷰/제보 작성) 진입 후 Back/page.goBack() 복귀. **11/11 통과**
4. `bfb3b4f` 다나 FE 이식 + 수정 3건 — 폼백 목업 제거(PM 결정, 감사 #5와 일관), 지역 필터 완화(일치 없으면 전체 표시 — 실데이터 location이 '구로구' 등이라 빈 화면 되던 버그), 빈 상태 추가. pubspec.lock 구버전 롤백 5건은 이식 제외 (브랜치 전략 사례)

**미완료/다음 세션에서 이어갈 것 (우선순위)**
1. ~~태관 4주차 과제 (찜 연동)~~ → ✅ **완료 (8/7, 9110c08 → 3e6a220 cherry-pick)** — 상세는 5-0 태관 항목. docId 정규화(감사 #6)는 BE 수정 필요라 후속 과제로 분리
2. 댓글·좋아요 백엔드 미구현 — 피드 카드 '댓글 0' vs 아래 목업 댓글 2건 불일치 상태로 라이브 중. 백엔드 추가 시 상세 화면 목업 _comments 제거 필요 (후속 과제 배정 필요)
3. Firebase 노출 키 폐기·재발급 + git 히스토리 purge (감사 #1) — 콘솔 작업, 여전히 미완료
4. 카카오/Gemini 노출 구 키 재발급 — 권장, 미완료
5. 공개 GET API 레이트리밋 일괄 적용 — 6주차 통합 안정화 때 (현재 AiController만 적용)
6. 피드 API 쿼터 — 호출마다 stores_user 전체 읽기. 제보 수 증가 시 인메모리 캐시 필요
7. ~~외부 AI 코드 리뷰(8/5)에서 확인된 정리 후보~~ → ✅ **해결 (8/7, 5-9 참조)** — home_map 미사용 선언 8건·report_create 미사용 필드 3건 정리 완료 + 개발용 어드민 모드 제거. 남은 것: withOpacity deprecated 등 info 레벨 43건 (기능 무관, 6주차 폴리싱 때 검토). 단, 그 리뷰의 담당자 배정은 구버전 TODO 주석 인용이라 무시 (어드민은 웹 전환됨, 찜 API는 완료됨, 문의는 민서 5주차)

**다음 세션 작업 팁 (이번 세션에서 겪은 환경 문제)**
- 터미널 명령은 1초 이내로 짧게. 오래 걸리는 작업(빌드/QA/배포 대기)은 `> /tmp/xxx.log 2>&1 &` 백그라운드 실행 후 `sleep 30 && tail` 폴링으로 확인 — foreground sleep 300 같은 긴 대기 명령이 세션 중단 원인이었음
- 재부팅 후 /tmp/howmuch-qa의 playwright가 날아가 있을 수 있음 → QA 전 `ls node_modules/playwright` 확인, 없으면 `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install playwright` (브라우저는 ~/Library/Caches에 남아있음)
- qa_v6.js 필수 컨텍스트: viewport 390x844, deviceScaleFactor 2, geolocation 권한, addInitScript로 'flutter.onboarding_completed'='true', 로드 후 9초 대기 + flt-semantics-placeholder 클릭

## 5-7. 8/7 찜 후속 구현 (PM 직접 — WEEKLY_PLAN 미포함 항목 2건)

**배경**: 태관 찜 연동(3e6a220) 리뷰에서 확인된 후속 3건 중 추후 개발 일정에 없는 2건을 PM이 직접 구현. ② 게스트 하트 → 로그인 유도는 5주차 태관 "자동 로그인 재구현"과 같은 작업 단위(401 처리 UX)라 보류.

1. **감사 #6 — 찜 docId 이스케이프 (BE)**: FirebaseService favoriteDocId에 sanitizeForDocId 추가 ('_'→'__', '/'→'_s' 순 이스케이프 — 단사 함수라 매장명 충돌 없음). 매장명에 '/' 있어도 찜 정상 동작. removeFavorite는 구 형식(비이스케이프) docId도 함께 삭제해 이전 데이터 호환 유지.
2. **찜 카드 매장 메타 (BE+FE)**: GET/POST /api/favorites 응답에 industry·menu1·price1·address 추가 — 공공데이터 인메모리 캐시에서 매장명 매칭이라 **Firestore 읽기 0** (제보 매장 등 캐시 미스는 null → 프론트는 기존 placeholder 유지). FavoriteResponse DTO 4필드 추가. 프론트 FavoriteStoreModel.fromJson이 메타 표시: 배지 '착한가격업소', 업종별 이모지, 대표메뉴, 가격("5000"→"5,000원" 수동 포맷 — intl 의존성 추가 회피).
3. **커뮤니티 피드 위치 현위치화 (984c32a, FE)**: 사용자 리포트로 발견 — 피드 상단 위치 칩이 목업 '역삼동/합정동' 탭-순환이었음. geolocator 현위치 → 카카오 coord2regioncode 역지오코딩(profile_setup_screen과 동일 패턴·키)으로 행정동명(region_3depth_name, region_type='H' 우선) 표시. 조회 전 '내 동네', 권한 거부/실패 시 '전체' 폼백 (피드 목록은 어차피 전체 표시라 기능 영향 없음). 탭-순환 제거(칩은 읽기 전용). analyze 57(main 동일) + build web ✅ + 배포 완료.
- 검증: compileJava ✅ + flutter analyze 57(main과 동일·신규 0) ✅ + build web ✅ → 커밋 후 push/배포
- ⚠️ **이번 세션 함정**: replace_in_file 도중 세션 비정상 종료가 2건 발생하며 파일이 손상됨 — ① FirebaseService.java 첫 줄에 'ㅡ' 오타 삽입 → compileJava가 "class, interface, enum, or record expected"를 전 줄에 다발 (원인은 첫 줄 1글자) ② mypage_state.dart 문자열 깨짐 + '!!' 중복. **교훈: 편집 후 `git diff | grep '^+'`로 의도한 변경만 들어갔는지 반드시 확인** — 손상 잔해는 diff에서 바로 보임.

## 5-8. 5주차(8/11~8/17) 과제 단톡 공지 발송 (8/7)

4주차 전원 완료 공지와 함께 5주차 과제 발송 완료. 요지:

- **지환 (BE)**: GET /api/notifications (내 알림 목록, 최신순) + POST /api/notifications/{id}/read (읽음 처리, 본인 알림만). Firestore `notifications` 컬렉션 신규 (userId/title/body/type/isRead/createdAt). favorites 패턴 참고, uid는 세션 attribute에서만, 목록은 whereEqualTo + 메모리 정렬 (인덱스 불필요). 테스트 데이터 2~3건 수동 삽입 + 완성 시 응답 JSON 단톡 공유 (다나 연동용).
- **다나 (FE)**: 알림 화면 + 알림 설정 연동. API 나오기 전 로딩/빈/에러 상태부터. analyze 신규 이슈 0 + build web.
- **태관 (FE)**: 자동 로그인 재구현 — 스플래시 토큰 → /api/user/profile 검증 → 200: authState 복원+홈 / 401: clearSession+로그인 (방법 상세는 5-1 항목2·5-2 참조). CORS 401 수정(4bec04b)으로 전제조건 해소됨. 덤: 게스트가 매장 상세 하트 누륾면 '로그인이 필요해요' 유도 (5-7 ② 보류분과 동일 맥락).
- **민서 (PM)**: 문의 API + /api/admin/inquiries, 회원 탈퇴(DELETE /api/user), 오늘의 픽(기상청 연동).
- 공통: 개인 브랜치 커밋 → 통째 머지 금지(선별 이식), main push는 PM이 모아서 (Render 재배포 비용).

## 5-9. 8/7 미사용 코드 정리 + 개발용 어드민 모드 제거 (PM)

**미사용 코드 정리 (flutter analyze warning 16건 전부 해소)**:
- `errors/report_delete_confirm_screen.dart` — 구버전 중복 파일 삭제 (라우터는 `system/` 신버전만 사용, diff로 구버전 확인 후 제거)
- `report_create_screen` 미사용 필드 3건 (`_storeOptions`/`_addressOptions`/`_isSubmitting` + 관련 setState·try-finally 정리)
- `home_map_screen` 미사용 선언 8건 + 연쇄 미사용 2건 (`_industryKeywords` 맵, `_TrianglePainter` — 각각 `_matchesIndustryFilter`·`_PriceMarker` 전용) — 233줄
- search 화면: `search_filter`의 `muted` 필드, `search_result`의 `dart:convert` import·`_recentSearches`·`_RecentSearchesWidget` — 73줄
- `profile_setup_screen`의 `_surface`, `report_service`의 `_ref` 생성자 주입 제거
- 백엔드(Java)는 전수 조사 결과 미사용 클래스 없음 (FirebaseTokenResponse·StoreDto 등 전부 사용 중 확인)

**개발용 어드민 모드 제거**:
- 배경: 어드민은 8/3 웹 페이지(`web/admin.html`) 전환 결정. 앱 내 어드민 화면 2개는 100% 목업(하드코딩 데이터, API 호출 0건, 마이페이지 토글에 "관리자 권한 API가 붙으면 이 개발용 토글은 제거" TODO 명시)
- 삭제: `lib/features/admin/` 전체(3개 파일 2,404줄), `/admin/reports`·`/admin/inquiries` 라우트, 마이페이지 '개발용 관리자 모드' 토글 + 조걶부 메뉴 2개 + `_AdminModeRow` + `_qaBadgeText`, `AuthState.isAdmin` 필드 (참조 3곳: login/withdrawal/session_expired 정리)
- 유지: `_AdminModeSwitch` 위젯은 `_ToggleRow`(푸시·마케팅 토글)가 재사용 중이라 유지
- `widget_test.dart` 어드민 테스트 3개 + 관련 expect 3줄 제거 (제거된 기능의 테스트)

**검증**: flutter analyze 60 → **43 issues** (전부 기존 info 레벨 — withOpacity deprecated 11곳 등, 기능 무관) · **error 0 · warning 0** + `build web` 성공. 각 단계마다 grep 참조 검증 + git diff 확인, 대형 파일은 라인 기반 Python 패치(assert 검증 포함) 사용. ⚠️ `flutter test` 9개 실패는 **레거시 스위트가 변경 전부터 깨진 상태** (첫 실패가 어드민 무관한 온볼딩 테스트 — 기대 텍스트 '정부 인증 · 공공데이터'가 앱에 존재하지 않음). 팀 검증 기준(analyze + build web + Playwright)과 동일하게 통과. widget_test 전면 정비는 6주차 통합 테스트 과제로.

**환경 메모**: 이 세션에서 디스크 99% 사용(여유 174MB)으로 flutter test 컴파일 ENOSPC + 세션 중단 발생 → `~/Library/Caches`의 ShipIt 계열 업데이트 잔재(VSCode 1.5GB·antigravity 0.7GB) + JetBrains 캐시(1.8GB) 정리로 5.6GB 확보. **빌드/테스트 전 `df -h` 확인 습관화 권장** (5-0-1의 ENOSPC 사고와 동일 패턴).

## 5-10. 8/7 README 포트폴리오 개편 + push·배포 상태

**README 개편 (f06e88e + abf5995)**:
- 심사/포트폴리오형 전면 개편: 히어로(로고·기술 배지 6개·라이브 링크), 주요 기능 표 9개, 기술 스택, 아키텍처 다이어그램, 프로젝트 구조, 실행 방법, 팀, 문서 링크
- 구버전 정보 정리: 제거된 개발용 어드민 토글 설명, 완료된 "2주차 목표", 구 브랜치 전략(PR 병합→선별 이식)
- 팀 협업·AI 프롬프트·Figma 회고·환경 설정 주의사항은 **docs/TEAM_GUIDE.md로 분리** (신규)
- 스크린샷 3종 (docs/images/): Playwright 캡처 — home.png·explore.png는 라이브(howmuch-zeta, 카카오맵 정상 도메인), mypage.png는 로컬 최신 빌드(어드민 토글 없는 신버전). 캡처 스크립트: /tmp/howmuch-qa/shots_v3.js (재사용 가능)

**웹 캡처 시 확인된 함정 3가지** (qa_v6 팁 보강):
1. 이 프로젝트 웹 빌드는 **path URL 전략** — `/#/path` 해시 접근 무시됨 (SPA 서버 필요 시 모든 경로를 index.html로 fallback)
2. 스플래시는 온볼딩 완료 후 무조건 로그인 화면 이동 → 캡처는 '로그인 없이 둘러보기' 클릭으로 게스트 진입
3. 하단 네비는 시맨틱 DOM에 안 잡힘 → 좌표 클릭(390x844 기준 탐색 115/리포트 272/마이 350, y=812). 일반 버튼은 `flt-semantics` JS 클릭 (placeholder는 page.evaluate로 활성화)

**push·배포 (8/7)**:
- `git push origin main` 완료 (df72d68..abf5995 — 7개 커밋: 0e480da 5주차 과제 + 이번 세션 4개 + docs 2개) → **Render 자동 배포 트리거됨**
- ~~WEATHER_API_KEY Render env 미등록~~ → ✅ **해결 (8/7 저녁)** — 키 등록 후 403 `SERVICE_KEY_IS_NOT_REGISTERED_ERROR` 발생: 원인은 키 인코딩 (Encoding 키의 `%`가 RestTemplate String URL 방식에서 이중 인코딩). **97088a4에서 수정**: 키에 `%` 포함 시(Encoding) 그대로 + 없으면(Decoding) URLEncoder 인코딩, 그리고 String 대신 `URI.create()`로 전달해 재인코딩 방지. **양쪽 키 형식 모두 지원**. 라이브 검증: `weatherAvailable:true, 맑음, 34°` 정상. **교훈: 공공데이터포털 키는 Encoding/Decoding 2종 제공 — 어떤 키를 쓰든 동작하는 방어 코드가 정답**
- ⚠️ **웹 Vercel 재배포 미실시** — 라이브 웹(howmuch-zeta)은 어드민 토글·신규 README 미반영 구버전. 재배포 시: `flutter build web --release` → `cd build/web && npx -y vercel@latest deploy --prod --yes` (배포 전 `npx vercel projects ls`로 howmuch 프로젝트 확인 — 5-2 함정 참조)

## 5-11. 8/7 오늘의 픽 추천 로직 신빙성 점검·수정 (PM)

**배경**: 8/7 라이브 정상화 후 추천 결과가 실제로 믿을 만한지 검증 요청. 코드 + 스냅샷 데이터(11,207건)로 시뮬레이션 점검.

**발견된 문제 5건 (전부 수정)**:
1. **비식당 추천 가능** — 공공데이터엔 미용업 1,555·세탁업 202·목욕업 112 등 비요식업 3,000건+ 포함. 키워드 매칭 실패 시 전체 풀에서 거리순 선정 → 미용실이 "오늘의 픽"으로 나올 수 있었음. → `FOOD_INDUSTRIES` 화이트리스트(한식·중식·일식·양식·기타요식업)로 식당만 추천.
2. **날씨/기온이 '지금'이 아닐 수 있음** — getVilageFcst 100행을 순회하며 SKY/PTY/TMP를 덮어쓰기 → 리스트 마지막 예보 시각(수 시간 뒤~익일 새벽) 값이 표시되던 구조. → 슬롯(fcstDate+fcstTime)별로 모아 현재 시각과 가장 가까운 슬롯만 사용 (미래 우선, 없으면 최근 과거).
3. **자정~새벽 2시 날씨 조회 실패** — latestBaseTime이 0~1시에 "0200" 반환 + base_date는 오늘 → 아직 발표 안 된 시각이라 빈 응답. → 발표 지연(+15분) 버퍼를 두고, 당일 첫 발표(02시) 전이면 전날 23시 발표분으로 역행.
4. **날씨 격자 서울 고정** — 사용자 lat/lng는 거리 정렬에만 쓰이고 날씨는 전국 어디서나 서울 시청 기준. → 위경도→기상청 격자(Lambert Conformal Conic, 5km) 변환 공식으로 사용자 위치 날씨 조회.
5. **추천 결과 고정·풀 빈약·오매칭** —
   - 같은 날씨·같은 위치면 매번 동일한 4곳 → 후보군 상위 20건을 날짜 시드로 셔플 (같은 날 안정적, 다음 날 순서 변경)
   - 더운 날 키워드(냉면/빙수/샐러드 등) 매칭이 105건(0.9%)뿐 → 콩국수·메밀 추가 (스냅샷 실재 메뉴 기준)
   - '탕' 키워드에 탕수육 9건 오매칭 → '탕' 제거하고 설렁탕·갈비탕·곰탕·삼계탕·전골·순두부 등 구체 메뉴로
   - 흐린 35° 폭염이면 국밥 추천 → 기온 우선 분기로 변경 (28°↑ 시원 메뉴, 5°↓ 따뜻 메뉴, 하늘 상태와 무관하게)

**수정 파일**:
- `WeatherService.java` — getCurrentWeather(Double lat, Double lng)로 변경, 슬롯 선택, base_time 역행, toGrid 추가, TMP 파싱 보강("34.0"도 허용)
- `RecommendationController.java` — getCurrentWeather(lat, lng)로 호출 변경
- `FirebaseService.java` — FOOD_INDUSTRIES, CANDIDATE_POOL_SIZE, MAX_PICKS 상수 추가. getTodaysPicks: 식당 필터 + findMatchedMenu(실제 매칭 메뉴 반환, matchedMenu 필드 추가) + 가까운 상위 20건 셔플 + 중복 매장명 제거. weatherKeywords: 기온 우선 분기, 구체 메뉴 키워드로 교체

**검증**: compileJava 통과 ✅ + 실제 스냅샷 데이터 시뮬레이션 5케이스 ✅ (맑음34°→냉면·칼국수, 비22°→찌개·순두부, 맑음2°→순두부·국수, 흐림33°→냉면, 맑음15°→국수·덮밥 — 매칭 건수 446~3,386건, 전부 식당만)

**남은 참고사항**: matchedMenu 필드는 API 응답에 추가됨(프론트는 아직 미사용, 카드는 기존처럼 menu1 표시 — 후속 폴리싱 때 matchedMenu로 교체 가능). **배포는 아직 안 됨** — 백엔드 push 시 Render 자동 배포.

## 6. 알려진 주의사항
- Render 물묣 인스턴스는 슬립/휘발성 디스크 (classpath 스냅샷이 유일한 영속 캐시)
- Firestore 쿼터: 유저 데이터(리뷰/제보/프로필/방문)만 읽음. 대량 조회 신규 추가 시 캐시 패턴 필수
- 웹에서 debugPrint는 릴리스 빌드에서 묵력 — QA는 Playwright로
- 토큰 절약: 작업 단위로 새 채팅, 이 문서로 상황 인계
