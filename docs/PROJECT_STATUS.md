# 얼마에요 프로젝트 현황 (핸드오프 문서)

> 새 세션/팀원이 이 파일 하나로 상황 파악. 최종 갱신: 2026-08-20
> 운영 애플리케이션 기준 커밋: `bece515`. 8/19 전체 안정화 변경과 8/20 Render 기동 복구를 main에 push하고 Render/Vercel 운영 배포까지 완료했다. 상세는 5-32 참조
> 8/13 **다나·태관 통합 보완 완료**: 팀원 브랜치를 통째로 머지하지 않고 과제 변경만 선별 이식·보완했다. 최초 Spark 릴리스에서는 이미지를 비활성화했으나, 후속으로 Cloudinary Free 저장소를 도입해 사진 첨부까지 배포했다.
> 8/13 **빈 리뷰 생성 차단 배포·QA 완료**: 빈 폼은 필드 오류만 표시하고 리뷰 수를 늘리지 않음. 유효 리뷰의 `price`·`authorUid` 저장 후 QA 데이터 삭제·원복까지 확인했다.
> 8/13 **제보 사진 실서비스 E2E 완료**: 사진 선택·미리보기 → 백엔드/Cloudinary 업로드 → 제보 저장·상세 재조회 → 사진 제거·원본 404 → QA 문서 삭제·목록 원복까지 확인했다.
> 8/13 **6주차 민서(PM) 선행 개발 배포 완료**: 제보 삭제·Cloudinary 사진 연쇄 삭제, Firestore 보안 룰, 주간 공공데이터 스냅샷 PR, Cloudinary 사용량 모니터링과 통합 회귀 테스트를 `8eb9952`로 main에 반영하고 운영 설정·배포·비파괴 QA까지 완료했다. 상세는 5-21~5-22 참조.
> 8/13 **방문 위치 인증·목업 제거 main QA 완료(배포 전)**: 민서 브랜치에서 자동 QA를 통과한 뒤 로컬 `main`에 반영했다. 매장 좌표로 GPS 거리를 계산해 50m 이내만 인증하고, 서버는 인증 방식·거리만 저장한다. 검색·상세·계정 화면의 가짜 데이터도 제거했다. 실기기 위치 권한 QA와 운영 배포는 아직 수행하지 않았다. 상세는 5-23~5-25 참조.
> 8/13 **내 위치 반응성·문의 답변 흐름 main 반영 완료(배포 전)**: 캐시 위치 우선 이동으로 지도 버튼의 첫 반응을 개선하고, 어드민 답변 → 사용자 문의 내역·알림함 확인까지 연결했다. 웹은 앱 안 알림함을 지원하되, 브라우저 종료 후 시스템 푸시는 아직 지원하지 않는다. 상세는 5-26 참조.
> 8/17 **우선순위 1 배포·검증 완료**: 방문인증 화면 진입 시 `Store` 전체 객체를 전달하도록 수정하고, 백엔드 테스트·알림 회귀 테스트·50m 정책 테스트·웹 릴리스 빌드를 통과했다. 실제 휴대폰 GPS 권한/50m 경계와 가격 변동 알림 전체 흐름은 실사용 QA가 남아 있다.
> 이전 주요 기능 기준: 24b8be2 (자동 로그인·게스트 찜 방어·동네제보 댓글/답글/좋아요/알림 연동), 후속 커밋 afa502d·81c8da6 — 상세는 5-15 참조
> 8/11 **어드민 확장**: 댓글 관리(목록·삭제) / 문의 관리(목록) / 알림 발송(전체·특정 회원) + 커뮤니티 통계 — 상세는 5-14 참조
> 8/10 **동네제보 댓글/답글/좋아요/알림구독 백엔드 전면 구현** (태관 요청 7개) + **지환 알림함 선별 이식** + SessionAuthFilter 경로 누락 버그 수정 — 상세는 5-13 참조
> 8/8 **개인정보처리방침 초안 완성** (`docs/PRIVACY_POLICY_DRAFT.md`) + 감사에서 코드 이슈 4건 발견 — 상세는 5-12 참조
> 8/7~8/8 **의사결정 4건 기록**: Swagger 도입 시기(마지막) / PC 웹 풀와이드(홈 지도만, 6주차 후보) / 거지맵 데이터(실DB 적재 비추) / 개인정보 방침 — 상세는 5-12 참조
> 8/7 **오늘의 픽 추천 로직 신빙성 점검·수정 완료** — 상세는 5-11 참조 (백엔드+프론트 모두 배포 완료)
> ~~웹 Vercel 재배포 미실시~~ → ✅ **해결 (8/7 저녁)** — 오늘의 픽 테마 칩 + 위치 전달 + 지도 목업 제거 후 재배포 완료
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
- **배포 API(d46a877)**: /api/auth/kakao, /api/stores/all·bounds, /api/review(GET/POST·me), /api/report/store·my, /api/user/profile, /api/ai/chat, /api/visits, /api/public-data/sync, /api/favorites(GET/POST/DELETE), /api/savings/goal(GET/POST)·history·stats. 6주차 브랜치에서는 무인증 public-data sync를 제거하고 관리자 POST로 교체했다.
- **리뷰 프론트**: Review 모델 + storeId(매장명) 키 맵 상태, 목록/작성 API 연동 완료
- **웹 SPA**: vercel.json + web/vercel.json (빌드 산출물에 자동 포함) — 하위 경로 새로고침 200

## 3. 최근 버그 수정 (7/23, 커밋 해시 869532a0 기준)
1. 웹 카카오맵이 서울 중심 기본값으로 표시 + 현위치 버튼 미동작 → 맵 객체 비동기 등록 레이스. `home_map_screen.dart` `_initWebMap`에 3초/8초 지연 재시도
2. 마이페이지 "내 제보 상태" 재접속 시 사라짐 → `mypage_screen.dart` ConsumerStatefulWidget 전환 + initState에서 `reportService.fetchMyReports()` 재조회
3. 매번 온보딩 표시 → `splash_screen.dart`에서 SharedPreferences `onboarding_completed` 분기, `kakao_login_service.dart` 로그인 성공 시 플래그 저장
- 주의: geolocator 12.0.0은 `getCurrentPosition(desiredAccuracy:, timeLimit:)` 구형 파라미터가 정상 API (locationSettings 없음)

## 4. 배포 방법
- **백엔드**: `git push origin main` → Render 자동 배포 (자바 빌드 ~5-8분)
- **웹**: `flutter build web --release --no-wasm-dry-run` → 저장소 루트에서 `npx -y vercel@latest deploy build/web --project howmuch --local-config vercel.json --prod --yes` (다른 Vercel 프로젝트로 잘못 연결되는 것을 막기 위해 프로젝트를 명시)
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
11. **Swagger(springdoc-openapi) 도입** → **PM 결정 (8/7): 개발 전부 끝난 후 마지막에 도입** (7주차 QA·출시 버퍼 주간). 도입 시: build.gradle에 `springdoc-openapi-starter-webmvc-ui` 1줄 + /api/admin/** 는 @Hidden/GroupedOpenApi로 문서에서 숨김 + Bearer Authorize 버튼 설정. BE→FE 핸드오프 문서 자동화 + 포트폴리오 링크 효과.
12. **개인정보처리방침 (8/8)**: 실제 코드 전수 감사 + 한국 개인정보보호법 기준 방침 초안 완성 → `docs/PRIVACY_POLICY_DRAFT.md`. **감사에서 발견한 코드 이슈 4건**: ① 탈퇴 시 inquiries(문의 내역) 삭제 누락 (deleteUser에 추가 필요) ② 기존 앱 내 방침 화면(privacy_policy_screen.dart)이 허위 템플릿 (네이버/애플 로그인·프로필 사진·기기정보 수집·결제기록 5년 등 실제 없는 수집 기재) → 초안으로 교체 필요 ③ iOS 마이크 권한 문구 불필요 (사용 코드 없음) ④ 로그인 동의가 "간주" 문구뿐 (명시적 동의 체크 검토). 방침 빈칸: 사업자명·책임자 연락처·시행일·Firebase/Render 리전(국외 이전 고지 여부 결정). **7주차 스토어 등록 준비(개인정보처리방침 필수) 과제의 산출물로 사용.**
13. **PC 웹 풀와이드 레이아웃 (논의 8/7)**: 거지맵식 데스크톱 레이아웃 — **홈 지도만** 데스크톱 브레이크포인트(≥1024px)로 풀와이드+사이드 패널 적용 제안 (전체 화면 반응형은 비추, 40개 절대좌표 화면 재작성 부담). 6주차 태관 폴리싱 과제 후보. FigmaMobileCanvas maxWebWidth 430 고정이 현재 제약.
14. **거지맵 데이터 추출 검토 (8/7)**: 기술적으로 가능 확인 (api.hobos.studio 마커 API 무인증 bbox 쿼리, 샘플 10건 /tmp/geojimap_sample.json) — 그러나 **경쟁사 UGC라 실DB 적재는 부정경쟁방지법 리스크로 비추천** (PM 판단). 개발용 목업/벤치마킹 용도로만.

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

## 5-11. 8/7 오늘의 픽 추천 로직 신빙성 점검·수정 + 테마 다양화·위치 기반 추천 (PM)

**배경**: 8/7 라이브 정상화 후 추천 결과가 실제로 믿을 만한지 검증 요청. 코드 + 스냅샷 데이터(11,207건)로 시뮬레이션 점검. 추가로 "덥다고 냉멸만 추천하면 단조롭다"는 피드백으로 테마 다양화 + 위치 기반 추천을 구현.

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

**추가 개선 (8/7 저녁, 커밋 `e44e138`·`31175b3`·`9ccaf86`·`753a443`)**:
- **테마 다양화 (BE+FE)**: 메인 테마 3곳 + 대안 테마 1곳 구조. 폭염에도 '이열치열' 삼계탕·국밥, 비 오면 '파전', 추우면 '매콤하게' 떡볶이·마라탕. 각 추천에 `matchedMenu`(실제 매칭 메뉴)·`theme`(테마 라벨)·`reason`(이유 멘트) 추가. 프론트 카드에 테마 칩(오렌지)·이유 멘트 표시.
- **위치 기반 추천 (FE)**: 오늘의 픽 화면이 지도 확보 위치(globalUserPosition) 또는 geolocator 조회 후 API에 lat/lng 전달. 없으면 서버 서울 기본 격자 폼백.
- **지도 오늘의 픽 카드 목업 제거 (FE)**: '따뜻한 국물 메뉴 3곳' 목업 → '날씨 기반 추천 4곳', 기온 '18°' 목업 → '오늘' 텍스트.

**수정 파일**:
- `WeatherService.java` — getCurrentWeather(Double lat, Double lng)로 변경, 슬롯 선택, base_time 역행, toGrid 추가, TMP 파싱 보강
- `RecommendationController.java` — getCurrentWeather(lat, lng)로 호출 변경
- `FirebaseService.java` — FOOD_INDUSTRIES, CANDIDATE_POOL_SIZE, MAX_PICKS, MAIN_PICKS, ALT_PICKS, ALT_CANDIDATE_POOL_SIZE 상수. getTodaysPicks를 테마 기반으로 전면 개편 (matchTheme/nearestShuffled/addUnique/findMatchedMenu). weatherThemes: 기온 우선 분기 + 대안 테마
- `lib/features/recommendation/presentation/screens/todays_pick_screen.dart` — 테마 칩·reason·matchedMenu 표시, 위치 전달
- `lib/features/home/presentation/screens/home_map_screen.dart` — 오늘의 픽 카드 목업 제거

**검증**: compileJava 통과 ✅ + flutter analyze 신규 이슈 0 ✅ + build web 성공 ✅ + 실제 스냅샷 데이터 시뮬레이션 5케이스 ✅ (메인 풀 446~3,346건, 대안 풀 28~834건, 전부 식당만)

**배포**: 백엔드 push 완료 → Render 자동 배포. 프론트 build web + Vercel 재배포 완료 (howmuch-zeta.vercel.app).

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

## 5-12. 8/7~8/8 비코드 의사결정 + 개인정보 감사·방침 초안 (PM 세션)

**1. Swagger(springdoc) 도입 시기 결정 (8/7)**: 효용은 인정(BE→FE 핸드오프 자동 문서화, 포트폴리오)하나 **개발 전부 끝난 후 마지막(7주차)에 도입**하기로 PM 결정. 지금 넣으면 매주 API 변경을 따라잡는 비용 발생.

**2. PC 웹 풀와이드 레이아웃 (8/7 논의, 미착수)**: 레퍼런스 = 거지맵(좌 매장 리스트 + 중앙 풀와이드 지도 + 우 피드 패널). 현재 제약 = `FigmaMobileCanvas.maxWebWidth = 430` 고정 중앙 정렬 (전 화면 40개+가 Figma 375px 절대좌표). **결론: 전체 반응형은 비현실적 — 홈 지도만 데스크톱 브레이크포인트(≥1024px)로 풀와이드 지도 + 좌측 매장 리스트 + 우측 오늘의 픽 패널** 적용 제안 (공수 1~2일 추정, 기존 provider 재사용). **6주차 태관 폴리싱 과제 후보**로 보류. 모바일(＜1024px)은 기존 레이아웃 유지, QA 뷰포트(390x844) 영향 없음.

**3. 거지맵 매장 데이터 추출 검토 (8/7, 적재 안 함)**: 거지맵은 Vite SPA + Supabase(api.hobos.studio). 지도 마커 API가 무인증 bbox POST 쿼리로 열여 있어 샘플 10건 수신 확인 (camelCase 파라미터, 상호/주소/카테고리/좌표/최신메뉴·가격 필드, 샘플: /tmp/geojimap_sample.json). **그러나 사용자 제보 가격 = 경쟁사 UGC라 실DB 적재는 부정경쟁방지법 리스크(잡플래닛 vs 사람인 판례) + 데이터 품질 문제(구내식당 혼입)로 비추천** — PM 판단 기록. 개발용 목업/벤치마킹 용도로만 사용 가능. 데이터 확장은 기존 공공데이터 + 카카오 로컬 API로.

**4. 개인정보 전수 감사 + 처리방침 초안 (8/8, 커밋 1839ab8)** → `docs/PRIVACY_POLICY_DRAFT.md`:
- **감사 방법**: 추측 없이 실제 코드 전수 조사 (FirebaseService/DTO 전체, AuthService, GeminiService, 로그인·권한·제보·문의·탈퇴 화면, 매니페스트, 호스팅 설정)
- **수집 17항목 표**: users(카카오id/이메일/닉네임/동네/관심카테고리/절약목표) + 제보/리뷰/방문/찜/문의 + 위치좌표(서버 미저장) + AI채팅(Gemini 전송) + 사진(로컬만, 업로드 없음) + 로컬 저장소 4종. 분석 도구(GA/Firebase Analytics/Crashlytics)·결제 **없음** 확인
- **외부 전송**: 카카오(로그인/지도/역지오코딩), Google Gemini(채팅 전문), 기상청(격자 좌표), Firestore/Render/Vercel/Google Fonts
- **삭제 실측**: 탈퇴 시 users+reviews+stores_user+visits+favorites 삭제됨. **inquiries 누락 (버그 — deleteUser에 없음)**
- **예상 못할 수집 8건**: ① 위치 버튼→카카오 직접 전송 ② 오늘의 픽 진입만으로 lat/lng 백엔드 전송 ③ AI채팅→Google 전송 ④ 세션 토큰에 카카오 회원번호 base64 평문 ⑤ 제보 DTO 통째 저장(phoneNumber/imageUrls 스키마 존재) ⑥ 사진 첨부해도 서버 미전송(오해 소지) ⑦ iOS 마이크 권한 문구 불필요 ⑧ **기존 방침 화면이 허위 템플릿**(네이버/애플 로그인·프로필 사진·기기정보·결제기록 5년 등 실제 없는 수집 기재)
- **방침 초안**: 법정 8항목 전부 포함(수집/목적, 보유기간, 파기, 제3자, 위탁, 권리행사, 책임자, 자동수집·쿠키). 코드로 확인 불가한 건 지어내지 않고 **빈칸 11개** (사업자명·시행일·책임자 연락처·문의 이메일·Firebase/Render 리전=국외 이전 고지 여부·로그 보관 기간·14세 미만 정책)
- **후속 코드 과제 4건**: ① deleteUser에 inquiries 삭제 추가 ② 방침 화면을 초안으로 교체 ③ iOS 마이크 권한 문구 제거 ④ 로그인 동의 "간주"→명시적 체크 검토
- ⚠️ 참고용 초안, 법률 자문 아님 — 실서비스 전 변호사 검토 필요. **7주차 스토어 등록 준비 과제의 산출물로 사용 예정**

## 5-13. 8/10 동네제보 댓글/좋아요/알림 백엔드 전면 구현 + 지환 알림함 이식 (PM, 커밋 6b738dd)

**배경**: 태관이 4주차에 동네제보 상세 화면(community_post_detail)을 만들면서 댓글/답글/좋아요/알림 API 호출 코드(community_service.dart)까지 미리 작성핸뒀으나, 백엔드가 없어 전부 실패하는 상태였음 (WEEKLY_PLAN에도 미배정 공백). PM이 직접 백엔드 전면 구현. **태관은 프론트 연동만 이어서 하면 됨.**

**구현된 API (전부 태관 프론트 community_service.dart 계약과 100% 일치)**:
| 기능 | 메서드·경로 | 응답 |
|---|---|---|
| 댓글 목록 | GET /api/community/feed/{postId}/comments | [{id, author, content, createdAt, isMine, replyCount}] |
| 댓글 작성 | POST /api/community/feed/{postId}/comments (body: content) | 생성 댓글 |
| 답글 목록 | GET /api/community/comments/{commentId}/replies | 답글 목록 |
| 답글 작성 | POST /api/community/comments/{commentId}/replies (body: content) | 생성 답글 |
| 좋아요 | POST·DELETE /api/community/feed/{postId}/like | {likes, likedByMe} |
| 알림 구독 | POST·DELETE /api/community/feed/{postId}/notification | {notificationEnabled} |
| 알림함 목록 | GET /api/notifications | [{id,title,body,type,isRead,createdAt}] (지환) |
| 알림 읽음 | POST /api/notifications/{id}/read | (본인 알림만, 지환) |

**신규 파일**: controller/CommunityCommentsController·CommunityFeedInteractionsController·NotificationController, dto/CommentRequest·CommentResponse·NotificationResponseDto. **수정**: FirebaseService(+271줄), SessionAuthFilter(+7줄).

**핵심 설계**:
- Firestore 신규 컬렉션 4개: `comments`(댓글+답글 통합, parentId로 구분), `feed_likes`, `feed_notifications`, `notifications`
- 좋아요·알림구독은 `uid + "_" + sanitizeForDocId(postId)` docId로 **멱등** (중복 추가 방지, favorites 패턴)
- **카운터 자동 갱신 (태관 요청 #6)**: 댓글/답글/좋아요 작성·삭제 시 `syncFeedCounts`가 comments·likes를 실제 컬렉션 기준으로 재계산해 stores_user 문서에 저장 → 목록/상세가 항상 최신
- **이미지 로컬경로 필터 (태관 요청 #7)**: saveUserReport에서 imageUrls 중 http(s) 아닌 기기 로컬 경로 제거 → 다른 기기/재실행 후 깨진 이미지 노출 방지. 실제 업로드(Firebase Storage 등)는 별도 과제
- 보안: uid는 세션 attribute에서만 주입(IDOR 방지), REJECTED·없는 글 404, 내용 1000자 상한, 인증 필요 시 401

**⚠️ 스모크에서 잡은 치명 버그 — SessionAuthFilter 경로 누락**: requiresAuth()에 `/api/community/`·`/api/notifications`가 등록돼 있지 않아 필터가 uid를 주입하지 않음 → 모든 인증 쓰기가 401. **라이브에서도 똑같이 터졌을 버그를 로컬 스모크에서 발견해 수정** (community는 GET=공개/비GET=인증, notifications=전부 인증). 이것이 처음 401이 난 진짜 원인 (토큰 문제 아님).

**isMine 직렬화 주의**: Lombok @Data는 `boolean isMine`을 JSON `mine`으로 직렬화 → 태관 명세 `isMine`과 불일치. CommentResponse에 `@JsonProperty("isMine")` 추가로 고정 (태관 프론트는 mine도 읽지만 명세 일치가 깔끔).

**로컬 스모크 전수 통과 (8081)**: 댓글 작성/목록/답글 작성/목록/좋아요 추가→취소→중복방지/알림 구독·해제/카운터 0→2(comments)·0→1→0(likes) 자동 갱신/공개 GET 비로그인 조회(isMine=false)/쓰기 401/없는 글 404/알림함 200.

**지환 알림함 선별 이식 (통째 머지 불가 판정)**: 지환 브랜치(origin/team/jihwan-backend, 알람 API 1·2차)에 **미해결 git 충돌 마커(`<<<<<<< Updated upstream`/`=======`/`>>>>>>> Stashed changes`)가 그대로 커밋돼 있음** — 1차(PATCH·uid 미검증)와 2차(POST·본인 검증)가 stash 충돌 상태로 섞임. → 2차(최신 의도) 기준으로 깨끗하게 재작성 + 팀 보안 원칙(500에 e.getMessage() 노출 금지) 적용. 지환 브랜치는 이식 후 폐기 가능.

**다음 과제**: 태관 FE — 동네제보 상세 댓글/좋아요/알림 연동 (백엔드 계약 일치 확인됨). 다나 FE — 알림함 화면 연동.

## 5-14. 8/11 어드민 페이지 대폭 확장 (PM, 커밋 cfad439)

**배경**: 동네제보 댓글/좋아요/알림 기능이 새로 생기면서(5-13) 이 데이터를 운영자가 관리할 어드민 기능이 필요해짐. 기존 어드민(제보/리뷰/회원/대시보드)에 커뮤니티 관리 기능을 추가.

**신규 백엔드 어드민 API** (전부 X-Admin-Key 인증, ADMIN_KEY 미설정 시 403):
- `GET /api/admin/comments` — 전체 댓글·답글 최신순 (id/postId/userId/content/createdAt/parentId/isReply)
- `DELETE /api/admin/comments/{id}` — 댓글 삭제. 댓글이면 소속 답글 전부 삭제 + 답글이면 부모 replyCount 감소 + 게시글 comments 카운터 갱신(syncFeedCounts)
- `POST /api/admin/notifications` — 알림 발송. body: {title, body, type?, targetUid?}. targetUid 없으면 전체 회원 발송. 제목 100자·내용 500자 상한. notifications 컬렉션에 문서 생성 → 다나 알림함 화면에서 조회됨
- `GET /api/admin/community/stats` — 커뮤니티 지표 (comments/feedLikes/feedNotifications/notifications 수, count 집계)

**web/admin.html 신규 탭 3개** (사이드바 '운영' 그룹):
- **댓글 관리**: 전체 댓글·답글 테이블 (구분 배지 댓글/답글, 내용 미리보기, 작성자·게시글 uid, 작성일) + 삭제(확인 모달)
- **문의 관리**: 전체 문의 테이블 (제목/카테고리, 내용 미리보기, 작성자, 상태 배지, 접수일) — 기존에 API만 있고 탭이 없던 것 추가
- **알림 발송**: 커뮤니티 통계 카드 3개(댓글·답글/좋아요/발송된 알림) + 발송 폼 (전체 회원/특정 회원 uid 탭 전환, 제목·내용 입력, 발송 확인, 발송 후 통계 갱신)

**추가 수정**: NotificationResponseDto의 `isRead`에 `@JsonProperty("isRead")` 추가 — Lombok @Data가 `boolean isRead`를 JSON `read`로 직렬화하던 것을 프론트 명세 `isRead`로 고정 (다나 알림함 연동용). CommentResponse의 isMine과 동일한 패턴.

**검증**: compileJava BUILD SUCCESSFUL + admin.html JS node --check 통과 + 로컬 스모크 (커뮤니티 통계 {comments:3,feedLikes:1,feedNotifications:1,notifications:0}, 댓글 목록 3건, 알림 발송 {sent:1} → smoketest 유저 알림함에 저장 확인, 댓글 삭제 {success:true}, 잘못된 키·무키 401).

**배포 (8/11 완료)**: 백엔드 push(5128206→358b837) → Render 자동 배포. 어드민 페이지 `flutter build web --release` → Vercel 재배포 완료. **라이브 검증**: 어드민 페이지(howmuch-zeta.vercel.app/admin.html) 새 탭 3개(comments·inquiries·notifications) 서빙 확인 + 새 어드민 API 무키 401 + 피드 공개 API 200.

## 5-15. 8/11 태관 FE 선별 이식 (origin/taegwan aaa9ff2 → main 24b8be2)

**배경**: `origin/taegwan` 통째 머지(5974cc0)는 공유 파일 16개·약 3천 줄을 한꺼번에 덮어써 18:39에 4cc4af2로 reset. 문서의 브랜치 원칙에 따라 최신 브랜치를 다시 fetch하고 기능 단위로 검토·이식함.

**이식 완료**:
- 자동 로그인: 스플래시에서 저장 토큰으로 `/api/user/profile` 검증. 200은 auth/profile 상태 복원 후 홈, 404는 프로필 설정, 401·403은 토큰 삭제 후 로그인. 일시적 네트워크/5xx는 토큰을 지우지 않고 네트워크 오류 화면으로 이동하며 `다시 시도`가 스플래시 검증을 재실행.
- 계정/찜 인증 UX: 로그아웃 시 로컬 세션과 프로필 상태 초기화. 게스트는 매장 상세에서 찜 목록 API를 호출하지 않고 하트 탭 시 `로그인이 필요해요` 안내. 내 리뷰 API 401도 로그인 필요 상태로 분류.
- 동네제보 상세: 목업 댓글 제거, 댓글·답글 목록/작성, 좋아요 추가·취소, 게시글 알림 구독·해제, 로딩·빈 상태·오류·재시도 UI 연동. 쓰기 기능은 게스트 사전 차단.
- 상세 사용자 상태: 공개 GET에서도 유효한 Bearer 토큰은 선택적으로 uid를 주입하고, 상세 응답에 `likedByMe`·`notificationEnabled`를 추가해 재진입 시 내 상태를 복원. 무토큰/잘못된 토큰은 기존처럼 공개 조회 가능.

**제외한 변경**: 브랜치 전체 머지, 기존 `main` 백엔드 구현 덮어쓰기, community_feed 로컬 파일 경로 처리(5-13에서 서버 필터 적용됨), 제보 화면 레이아웃 변경, store_detail 대량 포맷 변경. 필요한 메서드·조건문과 신규 `community_service.dart`만 이식.

**검증 (8/11 재점검 완료)**:
- 디스크: Flutter/Gradle 산출물 + Antigravity 업데이트 캐시 + Dart 분석 캐시만 정리해 여유 2.4GB → 4.0GB 확보. Playwright·Gradle·Pub 패키지 캐시는 유지.
- 백엔드: `./gradlew test` BUILD SUCCESSFUL. `FeedDetailResponseDtoTest` 신규 추가 — `likedByMe`·`notificationEnabled` JSON 키 직렬화 통과.
- Flutter: 신규 `community_service_test.dart` 3/3 통과(댓글 계약·답글 호환 키·좋아요 상태). 전체 레거시 `widget_test.dart`는 기존과 동일하게 5개 통과·9개 실패(삭제된 목업 문구/사용자명 기대, HTTP mock·WebView mock 부재 등 이번 이식과 무관).
- 정적 분석/빌드: `flutter analyze` 기존 info 43건(error 0·warning 0), `flutter build web --release` 성공(43초, `build/web` 44MB), `git diff --check` 통과.
- 라이브/브라우저: Render `GET /api/community/feed`·상세·댓글 모두 200, 상세에 `likedByMe`·`notificationEnabled` 확인. 로컬 release 웹 Playwright 기본 4화면 스모크 통과. 동네제보 상세는 실 API 좋아요 수 반영·댓글 빈 상태·좋아요/알림 UI·목업 댓글 제거·page error 0 전부 통과. 캡처: `/tmp/howmuch-qa/shots/community_detail_smoke.png`.
- 별도 발견: 기존 8/10 제보 1건에 만료성 `blob:` 이미지 URL이 남아 있어 화면은 `이미지 없음` 폴백 표시. 신규 저장분은 5-13의 서버 필터가 차단하며, 레거시 데이터 정리는 별도 과제.

**현재 상태**: 기능 커밋 24b8be2와 후속 문서/회귀 테스트(afa502d·81c8da6)까지 `origin/main` push 완료. Render 백엔드와 Vercel 웹 배포 완료. 실서비스 QA 결과와 후속 수정 우선순위는 5-16 참조.

## 5-16. 8/11 배포 URL 전체 클릭 QA + 관리자 QA (실서비스)

**대상**: `https://howmuch-zeta.vercel.app` 및 `/admin.html`. Chrome 실제 화면에서 게스트 → 카카오 로그인(`test123`) → 로그인 전용 기능 → 새로고침 세션 복원 → 관리자 기능 순서로 직접 클릭 검증. 운영 데이터 변경은 가역 테스트 후 원복했고, 회원 탈퇴·제보 승인/반려·방문 인증·알림 발송은 최종 실행하지 않음.

**정상 확인**:
- 카카오 로그인 직후 프로필/지역 조회, 매장 검색·카카오맵·상세·공공데이터 출처, 오늘의 픽 목록 로드
- 찜 추가/해제 및 찜 목록 검색, 커뮤니티 좋아요·알림 구독 추가/해제
- 댓글·답글 작성 API, 내 제보 4건/상태 필터/수정 폼, 내 리뷰, 절약 통계 기간 필터, 방문 기록 0회 조회
- 절약 목표 20,000원 → 20,001원 저장 확인 → 20,000원 원복
- 관리자 로그인/새로고침 세션 유지, 대시보드·제보 필터·리뷰/댓글/문의 조회, 회원 검색·활동 상세, 알림 전체/특정 uid 대상 전환
- 관리자 삭제 API/집계 갱신 확인. QA 생성 리뷰 1건과 댓글·답글 각 1건 영구 삭제 완료: 리뷰 3→2건, 댓글·답글 2→0건

**CRITICAL — 배포 차단 수준**:
1. **일반 사용자 세션 복원 실패**: 카카오 로그인 직후 기능은 동작하지만 `/mypage` 새로고침 후 `test123`이 `게스트`로 풀림. 동시에 기존 제보 카드 일부가 남아 인증 상태와 사용자 데이터가 섞임. 5-15의 자동 로그인 구현이 실서비스 새로고침에서 정상 동작하지 않음.
2. **빈 리뷰 제출이 실제 리뷰를 생성**: 리뷰 작성 폼을 비운 채 `리뷰 등록하기`를 누르면 필수값 오류 대신 이전/기본 값(`구사정육식당`, `생고기김치찌개`, `정말 좋은 매장이네요!`)으로 리뷰가 생성됨. 관리자에서 생성 사실 확인 후 삭제·원복 완료. 프론트 상태 초기화와 백엔드 필수값 검증을 함께 재점검해야 함.
3. **AI 추천 운영 실패**: 로그인 후 빠른 질문과 오늘의 픽 경로 추천 모두 `AI 응답을 가져오는 중 오류`. 경로 화면은 오늘의 픽과 다른 매장을 보여주며 총 거리 `0m`.
4. **방문 인증 화면 불능**: 검색 결과상 21.8km 거리 매장을 `현재 거리 320m`로 표시. 메뉴/8,000원 입력 후에도 예상 절약액이 계산되지 않고, 인증 방식·입력 영역이 실제 렌더링에서 빈 화면처럼 사라짐.

**HIGH — 실데이터/목업 혼재**:
- 매장 상세 상단 `4.6 · 리뷰 128 · 예상 절약 2,000원`은 목업인데 실제 리뷰 섹션은 1건/4.0으로 서로 불일치. 리뷰 목록 방문 후에야 상세 실제 개수가 갱신됨.
- 일반 알림함·가격 알림 매장/메뉴, 연결된 소셜 계정 이메일, 게스트 방문 기록/목표 진행률, 탈퇴 화면 집계가 고정 목업. 실제 마이페이지(제보 4·찜 2·절약 0원)와 탈퇴 화면(제보 2·찜 12·누적 24,500원)이 불일치.
- 문의 폼이 예시 제목/내용으로 미리 채워지고 답변 이메일이 `unknown`. 연결 계정 화면도 실제 계정과 무관한 카카오/Apple 이메일 표시.
- 앱 내 개인정보처리방침이 허위 템플릿(미사용 로그인 제공자·결제 기록·가상 담당자/이메일) 상태. 5-12의 실제 코드 기반 초안으로 교체 필요.
- 관리자 제보 전체 17건과 상태 합계(대기 5 + 승인 2 + 반려 3 = 10)가 불일치하며, 동일 시각·내용의 중복 제보도 존재.

**MEDIUM — UX/갱신 문제**:
- 댓글 작성 후 입력창이 비워지지 않고, 상세 댓글 2건이 피드 카드에서는 즉시 0건으로 남음.
- 사용자 제보 상세의 `문의하기` 버튼 무반응. 반려 사유는 사용자 화면에서 `반려`만 보이지만 관리자는 실제 상세 사유를 조회 가능.
- 게스트 절약/찜 API 실패가 로그인 안내 대신 일반 네트워크 오류로 표시됨. 리뷰 빈 제출도 화면상 검증 안내가 없음.
- 관리자 삭제 직후 대시보드 통계는 자동 갱신되지 않으며 `새로고침` 버튼 후 리뷰 2건으로 반영됨.
- 관리자 리뷰 목록에 작성자 `게스트`인 기존 리뷰가 1건 있어, 과거/현재 인증 없는 리뷰 생성 경로가 남아 있는지 데이터·API 감사 필요.

**최종 판정**: 태관 FE와 댓글/좋아요/알림·찜·제보·절약 관련 백엔드 API는 핵심 쓰기/조회에서 실제 연동됨. 그러나 자동 로그인, 리뷰 검증, AI, 방문 인증 및 광범위한 목업 혼재 때문에 **전체 연동 정상 완료로 판정할 수 없음**. 우선순위는 `일반 세션 복원 → 빈 리뷰 생성 차단 → AI 운영 설정/응답 → 방문 인증 렌더링·거리/estimate → 목업 제거` 순.

## 5-17. 8/13 다나 알림 연동 + 태관 자동 로그인·제보 이미지 보완 (배포·QA 완료)

**작업 원칙**: `main`에 팀원 브랜치를 통째로 합치지 않고 `codex/fix-team-integration`에서 과제 관련 변경만 선별 이식했다. 다나 브랜치의 사설 LAN API 주소·개인 iOS 서명/번들 ID·오래된 잠금파일 변경과 태관 브랜치의 공유 백엔드 덮어쓰기는 제외했다.

**김다나 — 5주차 알림 화면/알림 설정**:
- 알림 목록을 `GET /api/notifications`, 개별/전체 읽음을 실제 API에 연결하고 서버·네트워크 오류 때 가짜 알림 5개가 표시되던 폴백을 제거했다.
- 백엔드 계약의 `type: admin`을 공지사항으로 매핑하고 제목·본문을 함께 표시한다. 읽음 처리 실패 시 화면 상태를 되돌리고 재조회하도록 보완했다.
- 알림 설정의 랜덤 성공·지연 목업을 제거하고 `GET/PUT /api/notifications/settings`와 Firestore `notification_settings/{uid}` 저장을 구현했다.
- 방해 금지 시작/종료 시간은 실제 시간 선택기로 입력하고 `HH:mm` 형식을 백엔드에서도 검증한다.

**오태관 — 5주차 자동 로그인**:
- 실서비스 QA의 `/mypage` 새로고침 게스트 전환 원인은 토큰 검증 코드 부재가 아니라, Flutter 웹이 플랫폼의 하위 경로에서 시작하면서 `/splash`를 우회한 라우팅이었다.
- OAuth 콜백만 예외로 두고 모든 콜드 스타트가 `/splash`에서 시작하도록 `app_router.dart`를 수정했다. 저장 토큰 검증 후 auth/profile 상태 복원, 401 세션 정리, 일시적 네트워크 오류 재시도라는 기존 스플래시 정책이 하위 경로 새로고침에도 실행된다.
- 배포 URL에서 `/mypage` 새로고침 후 스플래시 세션 검증을 거쳐 `test123` 계정이 다시 복원되는 것을 두 번 확인했다.

**태관 6주차 버그픽스 선행분 — 제보 이미지/수정**:
- `origin/taegwan`의 `ac04f80` 레이아웃·이미지 표시 변경을 선별 반영하고, 업로드는 JPEG/PNG/WebP 바이트 시그니처만 허용하도록 프론트·백엔드를 함께 보강했다. 최대 3장·장당 5MB, 사용자별 시간당 20회 제한을 적용했다.
- Firebase Storage URL은 설정된 버킷과 로그인 사용자 소유 경로만 제보에 저장할 수 있다. 부분 업로드 실패·확정적 저장 실패 시 신규 파일을 정리하고, 계정 삭제 시 설정 문서와 사용자 Storage 경로도 정리한다.
- 제보 수정은 더 이상 화면에서만 성공 처리하지 않고 `PUT /api/report/store/{id}`로 실제 저장하며 소유권 검사, 상태 `PENDING` 복귀, 반려 사유 제거를 수행한다.

**검증 결과**:
- 백엔드 `./gradlew test`: BUILD SUCCESSFUL. 이미지 형식 탐지 테스트 포함.
- 신규 집중 Flutter 테스트 7개와 알림 설정 관련 기존 위젯 테스트 2개: 전부 통과.
- 전체 `flutter test`: 15개 통과·기존 레거시 9개 실패. 실패 항목은 삭제된 목업 문구 기대, 실제 HTTP 400, WebView mock 부재 등 5-15와 동일한 기존 부채이며 이번 수정 대상 테스트는 통과했다.
- `flutter analyze`: error 0·warning 0, 기존 info 43건. `flutter build web --release`: 성공.
- 로컬 릴리스 웹에서 스플래시 → 온보딩 3단계 → 로그인 화면을 직접 클릭 확인했고 브라우저 콘솔 error/warn은 0건이었다.

**8/13 배포 결정**:
1. Firebase Storage 사용에 Blaze(종량제) 전환이 필요해 이번 릴리스는 Spark를 유지한다. `REPORT_IMAGE_UPLOAD_ENABLED` 기본값을 `false`로 두어 제보 사진 선택 UI와 업로드 호출을 함께 숨겼다. 기존 원격 이미지 URL은 제보 수정 시 보존한다.
2. `FIREBASE_STORAGE_BUCKET`은 Render 필수 환경변수에서 제외했다. 백엔드 업로드 API는 버킷 설정이 없으면 계속 실패하도록 닫혀 있으며, 업로드 코드는 6주차 Storage 방식 결정 후 다시 활성화할 수 있다.
3. 배포 후 실계정 QA 범위는 하위 경로 새로고침 세션 복원, 알림 목록/읽음/설정 저장, 빈 리뷰 생성 차단으로 조정한다. 실제 이미지 업로드는 이번 배포 완료 조건에서 제외한다.
4. 5-16의 AI 추천, 방문 인증, 기타 목업 데이터 이슈는 이번 다나·태관 작업 범위 밖이므로 별도 해결 상태로 유지한다.

**현재 판정**: 다나와 태관의 5주차 과제는 **코드·자동 테스트·실서비스 QA 기준 완료**다. 이 시점에 이관했던 이미지 업로드는 같은 날 Cloudinary 방식으로 후속 완료했다(5-20).

## 5-18. 8/13 빈 리뷰 생성 및 게스트 리뷰 경로 차단 (배포·QA 완료)

**원인**: 리뷰 작성 화면이 내용이 비면 `정말 좋은 매장이네요!`, 메뉴가 비면 `선택 안함`을 요청에 자동 삽입했다. 별점은 4점, 방문·가격 확인은 체크된 상태로 시작했고 결제 가격은 화면에만 존재해 요청에 포함되지 않았다. 따라서 사용자가 실제로 입력하지 않아도 백엔드의 기존 content 필수 검증을 통과했다.

**프론트 수정**:
- 메뉴·결제 가격·리뷰 내용은 빈 상태, 별점은 미선택, 방문·가격 확인은 미체크 상태로 시작한다. 공공데이터의 메뉴·가격은 입력값이 아니라 힌트로만 표시한다.
- 메뉴 100자, 결제 가격 1원~1,000만원, 내용 2000자, 별점 1~5와 두 확인 항목을 제출 전에 검증하고 각 필드에 오류를 표시한다.
- 기본 리뷰 문구와 `선택 안함` 대체를 제거하고 앞뒤 공백을 정리한 실제 입력만 전송한다. 결제 가격도 정수 `price`로 리뷰 요청·로컬 모델에 포함한다.
- `_isSubmitting` 잠금과 버튼 비활성화를 추가해 연속 탭에 의한 중복 POST를 막는다. 비로그인 상태는 네트워크 호출 전에 안내한다.

**백엔드 수정**:
- `SessionAuthFilter`의 리뷰 POST 보호에 더해 컨트롤러와 저장 서비스에서도 세션 uid를 다시 확인한다. uid가 없으면 Firestore 쓰기 전에 401/예외로 차단한다.
- 입력 공백을 trim한 뒤 storeId·storeName·menu·content·stars·price를 다시 검증한다. price는 1원~1,000만원이며 기존 필드 길이 제한도 정규화된 값에 적용한다.
- 클라이언트 표시명이 비어 있으면 `게스트`가 아니라 `사용자`로 저장하며, 클라이언트가 보낸 빈 값에 서버가 리뷰 내용이나 메뉴를 임의 생성하지 않는다.

**운영 데이터 읽기 전용 감사**:
- `/api/admin/reviews`에는 현재 2건이 있으며 두 건 모두 `authorUid`가 `kakao:` 사용자로 저장돼 있어 무인증 작성 데이터는 아니었다.
- 8/10 리뷰 1건은 `authorName=게스트`지만 인증 uid가 있는 과거 표시명 폴백 데이터이고, 8/1 리뷰 1건에는 과거 기본문구 `정말 좋은 매장이네요!`가 남아 있다.
- 기존 2건은 삭제·수정하지 않았다. 이번 변경은 신규 생성 경로를 차단하며 과거 데이터 정리는 별도 운영 결정으로 남긴다.

**검증 결과**:
- 신규 Flutter 리뷰 검증/위젯 테스트 4개 통과: 빈 값 API 미호출, 유효값 trim·price 전달, 연속 제출 1회 제한 포함.
- 관련 Flutter 회귀 테스트 14개 전부 통과. 전체 테스트는 19개 통과·기존 `widget_test.dart` 9개 실패로 5-17과 같은 레거시 부채만 남았다.
- 백엔드 컨트롤러·인증 필터 신규 테스트와 전체 `./gradlew test` 모두 BUILD SUCCESSFUL.
- `flutter analyze`: error 0·warning 0, 기존 info 42건. `flutter build web --release` 성공. `git diff --check` 통과.

**실서비스 재검증**:
1. `test123` 계정에서 빈 폼 제출 시 별점·메뉴·가격·내용·방문 확인 오류가 각각 표시됐고, 관리자 리뷰 수는 2건에서 늘지 않았다.
2. 유효한 QA 리뷰 1건을 작성해 `menu=생고기김치찌개`, `price=9000`, `stars=5`, `authorUid=kakao:...`가 저장되는 것을 확인했다. 해당 QA 리뷰만 삭제한 후 기존 2건으로 원복됐다.
3. 무토큰 직접 `POST /api/review`는 401을 반환했고, 신규 `게스트`/기본문구 리뷰는 생기지 않았다.

**현재 판정**: 5-16의 빈 리뷰 생성 문제는 **코드·자동 테스트·실서비스 QA 기준 해결**됐다.

## 5-19. 8/13 main 배포 및 실서비스 회귀 QA

**배포**:
- 기능 커밋 `623146d` (`fix: harden team integrations and review validation`)를 `main`에 fast-forward한 뒤 `origin/main`으로 push했다. Render 자동 배포 후 신규 알림 설정 `GET/PUT`이 정상 응답해 신버전 기동을 확인했다.
- `flutter build web --release` 산출물을 Vercel `howmuch` 프로젝트에 수동 배포했다. 배포 ID는 `dpl_A13rg26drxX7EzCDfT2bdPmdJMFX`, 프로덕션 별칭은 `https://howmuch-zeta.vercel.app`이다.
- 후속 상태 문서 커밋은 `[skip render]`를 사용해 불필요한 백엔드 재배포를 막는다.

**배포 전 검증**:
- 백엔드 전체 `./gradlew test`: `BUILD SUCCESSFUL`.
- 이번 통합 범위 Flutter 테스트 12개: 전부 통과. 전체 `flutter test`는 20개 통과·기존 `widget_test.dart` 9개 실패로, 실패군은 이전과 동일한 레거시 목업 문구·HTTP 400·WebView test double 부재다.
- `flutter analyze`: error 0·warning 0·기존 info 42건. 웹 릴리스 빌드와 `git diff --check` 통과.
- 디스크 여유가 483MB까지 떨어져 재생성 가능한 npm·Playwright·Gradle·Dart 캐시, Flutter/Gradle 빌드 산출물, QA 임시파일만 정리했다. 배포 후 최종 여유 공간은 약 2.7GB다.

**실서비스 클릭 QA**:
- `/mypage` 직접 접속·새로고침 모두 `/splash` 세션 검증을 거친 후 홈으로 이동했고, 마이 화면에서 `test123`·제보 4건·찜 2건이 두 번 복원되는 것을 확인했다. 게스트 전환 문제는 재현되지 않았다.
- 알림함은 실데이터 1건을 표시했고, 개별 읽음 후 미읽 표시가 제거됐다. 알림 설정은 기존 값을 그대로 `PUT` 저장한 후 `알림 설정을 저장했어요.` 성공 안내를 표시했다.
- 제보 화면은 `방문 확인`만 표시하고 `메뉴판 사진 첨부`는 노출하지 않아 Spark 릴리스 플래그가 정상 적용됐다.
- 빈 리뷰·유효 리뷰·무토큰 401·QA 데이터 원복 결과는 5-18에 기록했다.
- 배포 직후 Render 무료 인스턴스 기동 중 첫 세션 검증이 네트워크 오류 화면으로 이동했지만, 공개 API 기동 후 `다시 시도`로 즉시 복구됐다. 무료 인스턴스 콜드 스타트는 운영 잔존 위험으로 남긴다.

**최종 판정**: 다나 알림 연동, 태관 자동 로그인/제보 수정, 빈 리뷰 차단은 **배포·실서비스 QA 완료**다. 이 시점에 비활성 상태였던 제보 이미지는 5-20에서 Cloudinary 대체 Storage로 활성화·배포·실서비스 QA를 완료했다. 5-16의 AI 추천·방문 인증·목업 혼재는 다음 우선순위로 유지한다.

## 5-20. 8/13 Cloudinary 제보 사진 업로드 배포 및 실서비스 E2E QA

**구현·운영 방식**:
- Firebase Spark 플랜을 유지하면서 제보 메뉴판 사진만 Cloudinary Free 저장소에 보관한다. 프론트에는 키를 두지 않고 Render의 백엔드 환경변수 `CLOUDINARY_URL`로만 인증한다.
- `ReportImageStorage` 추상화와 `CloudinaryReportImageStorage` 구현을 추가했다. JPEG/PNG/WebP, 최대 3장·장당 5MB 검증을 유지하고 `howmuch/report-images/{uid SHA-256}/{UUID}` 경로로 저장한다.
- 저장 URL은 HTTPS·Cloudinary 계정·버전·소유자 경로·확장자를 검증하고, 변환 파라미터·외부 계정 URL·인코딩 우회 경로는 거부한다. 제보 수정에서 제거한 사진, 저장 실패 중간 파일, 회원 탈퇴 시 사용자 경로를 정리한다.
- `REPORT_IMAGE_UPLOAD_ENABLED` 기본값을 다시 활성화하고 Firebase Storage 버킷 의존성을 제거했다. 저장소 미설정 시 업로드 API는 503으로 안전 실패한다.

**배포**:
- 기능 커밋 `d46a877` (`feat: enable Cloudinary report image uploads`)을 `origin/main`에 push했다.
- Render `howmuch_backend`에 `CLOUDINARY_URL`을 비밀 환경변수로 등록했고 배포 `dep-d9ucpf7avr4c73b9q4bg`가 Live 상태로 기동됐다.
- Flutter 웹 릴리스 빌드를 Vercel `howmuch` 프로젝트에 배포했다. 프로덕션 별칭은 `https://howmuch-zeta.vercel.app`, 해당 배포 URL은 `https://howmuch-jmjpnvfq0-minseo033s-projects.vercel.app`이다.

**배포 전 검증**:
- 백엔드 전체 테스트 14개와 `./gradlew build` 통과. Cloudinary URL 소유권·형식·삭제 검증 테스트를 포함한다.
- 관련 Flutter 테스트 4개 통과. 전체 테스트는 20개 통과·기존 `widget_test.dart` 9개 실패로 기존 레거시 실패군만 남았다.
- `flutter analyze`: error 0·warning 0·기존 info 42건. `flutter build web --release`, `git diff --check`, 비밀값 스캔 통과.

**배포 URL 실서비스 E2E**:
1. 저장된 로그인 세션으로 제보 화면에 진입해 테스트 PNG 1장을 선택했다. `사진 1장 첨부됨` 문구, 파일명, 썸네일이 정상 표시됐다.
2. `QA Cloudinary 사진 테스트 20260813` 제보를 제출해 접수 완료 화면을 확인했다. 내 제보 목록·상세와 관리자 제보 관리에서 같은 항목과 사진이 다시 표시됐다.
3. 관리자 데이터에서 저장 URL이 `https://res.cloudinary.com/.../howmuch/report-images/...png` 형식임을 확인했고 브라우저 error/warn 로그는 0건이었다.
4. 제보 수정에서 사진을 제거해 저장한 뒤 상세에서 이미지가 사라짐을 확인했다. 제거된 Cloudinary 원본 URL은 HTTP 404를 반환했다.
5. 방금 만든 Firestore 문서는 ID·QA 매장명·빈 `imageUrls`를 모두 검증한 뒤 1건만 삭제했다. 이후 관리자·사용자 목록에서 QA 항목 0건을 확인해 운영 데이터를 원복했다.

**남은 운영 과제**:
- 제보 자체의 사용자/관리자 삭제 API가 없어 QA 문서 정리에 서버 계정의 조건부 삭제를 사용했다. 제보 삭제 시 Cloudinary 사진까지 연쇄 삭제하는 공식 API와 관리자 삭제 버튼을 추가해야 한다.
- Cloudinary 기본 업로드 자산은 공개 URL로 제공되므로 메뉴판 외 인물·민감정보가 담긴 사진을 올리지 않도록 UI 고지와 개인정보처리방침 반영이 필요하다. 관련 사실관계는 `docs/PRIVACY_POLICY_DRAFT.md`에 갱신했다.
- 디스크 99%(여유 171MB)로 확장 프로그램 설치가 중단돼 재생성 가능한 npm·Gradle·Flutter 빌드 캐시를 정리했다. 최종 여유 공간은 약 854MB로 여전히 낮아 추가 운영 여유 확보가 필요하다.

**최종 판정**: 제보 사진 기능은 **프론트 선택·미리보기, 백엔드 검증·업로드, Firestore URL 저장, 사용자/관리자 재조회, 수정 시 원본 정리까지 실서비스에서 정상 연동**됐다.

## 5-21. 8/13 민서(PM) 6주차 선행 개발 (main 배포·운영 설정 완료)

**제보 삭제와 Cloudinary 연쇄 정리**:
- 사용자 `DELETE /api/report/store/{id}`와 관리자 `DELETE /api/admin/reports/{id}`를 추가했다. 사용자 요청은 세션 uid와 저장된 `reporterId`가 일치해야 한다.
- 저장된 소유자 경로에 속한 Cloudinary 사진을 먼저 삭제하고, 성공한 경우에만 관련 댓글·좋아요·알림 구독, Firestore 제보 문서와 사용자 제보 캐시를 제거한다. 사진 저장소 오류 시 문서를 남겨 안전하게 재시도할 수 있다.
- Flutter 내 제보 상세의 기존 무반응 버튼을 실제 삭제 확인·API 호출로 연결했다. 성공한 경우에만 목록과 프로필 제보 수를 갱신하며, 웹 어드민은 모든 상태의 제보 삭제와 사진 정리 건수를 지원한다.
- 회원 삭제도 문의·댓글·피드 좋아요·알림 구독·알림·알림 설정과 제보 연관 데이터를 빠짐없이 정리하도록 보강했다.

**보안·운영 자동화**:
- Flutter 앱에 `cloud_firestore` 직접 접근이 없음을 확인하고 Firestore 클라이언트 읽기·쓰기를 전부 거부하는 `firestore.rules`, `firebase.json`, 배포 절차 문서를 추가했다. Admin SDK 백엔드 요청은 룰과 무관하게 유지된다.
- 운영 인메모리 캐시를 안정된 순서로 반환하는 관리자 스냅샷 API와 1만 건 이상·필수 필드/좌표 99% 검증 스크립트를 추가했다. GitHub Actions는 매주 월요일 03:00(KST)에 검증된 classpath 스냅샷 변경 PR을 생성하거나 갱신한다.
- 하드코딩된 공공데이터 키와 무인증 `GET /api/public-data/sync`를 제거했다. 동기화는 `PUBLIC_DATA_API_KEY`가 설정된 서버에서 관리자 `POST /api/admin/public-data/sync`로만 시작하며 중복 실행을 차단한다.
- Cloudinary 사용량은 민감한 계정 필드를 제외한 뒤 `GET /api/admin/storage/report-images/usage`로 제공하고 5분간 캐시한다. 어드민 대시보드에는 크레딧 사용률과 저장 공간을 표시하며 조회 실패는 핵심 대시보드를 막지 않는다.

**검증 결과**:
- 백엔드 전체 `./gradlew test`와 `./gradlew clean build` 통과. 제보 소유권·삭제 순서·사진 실패 시 문서 보존·회원 연관 데이터·공공데이터 키 미설정·인증 필터 회귀 테스트를 포함한다.
- Flutter 전체 `flutter test` 32개 통과. 삭제 API 성공·실패·무인증, 성공 후에만 상태 갱신하는 위젯 테스트를 포함하며 기존 레거시 위젯 테스트도 현재 앱 동작에 맞게 복구했다.
- `flutter analyze`: error 0·warning 0·기존 info 42건. `flutter build web --release`, 어드민 원본/빌드 산출물 JavaScript 문법 검사, Firebase/Actions 구성 문법 검사와 `git diff --check` 통과.
- 기존 99% 디스크에서 재생성 가능한 캐시와 오래된 Xcode DeviceSupport를 정리해 최종 검증 전 약 5.3GB 여유를 확보했다.

**운영 반영 결과**:
1. GitHub 저장소 Secret `ADMIN_KEY`를 등록해 주간 스냅샷 워크플로가 운영 API를 호출할 수 있게 했다.
2. Render에 `PUBLIC_DATA_API_KEY`를 등록하고 새 백엔드를 배포했다. 과거 Git 이력에 포함된 기존 키 교체는 별도 보안 후속 과제로 남는다.
3. Firebase 프로젝트 `howmuch-c7e52`의 `(default)` Firestore DB에 클라이언트 전체 읽기·쓰기 거부 룰을 게시했다. Admin SDK 백엔드는 정상 동작한다.
4. `8eb9952`를 main에 fast-forward 반영해 Render와 Vercel 운영 배포를 완료했다.

## 5-22. 8/13 6주차 운영 배포 및 비파괴 QA

**배포**:
- 백엔드: Render 자동 배포 후 `GET /api/admin/storage/report-images/usage`가 관리자 인증으로 HTTP 200을 반환했다.
- 웹: Vercel production 배포 `dpl_DAX74f8GvogDMeo2s4dyg4MPDLeA`, 운영 별칭 `https://howmuch-zeta.vercel.app` 반영을 확인했다.
- 소스: 배포 시점의 로컬 `main`과 `origin/main`이 모두 `8eb9952fe6dc07aa0c4d8da8a05f9934f6a973d4`로 일치했다.

**운영 검증**:
- 관리자 인증 없이 `POST /api/admin/public-data/sync` 호출 시 401, 제거한 레거시 `GET /api/public-data/sync`는 404로 확인했다.
- Firestore REST 비인증 직접 읽기는 403으로 차단됐다.
- 운영 어드민에 로그인해 대시보드 통계와 Cloudinary 카드(저장 공간 117.4 KB), 최근 제보 목록을 확인했다.
- 제보 관리에서 대기 6건을 불러오고 `삭제` 버튼의 영구 삭제 경고창까지 확인한 뒤 취소했다. 운영 데이터는 변경하지 않았다.
- 실제 제보·Cloudinary 연쇄 삭제는 백엔드 자동 테스트로 검증했으며, 운영 데이터 파괴를 수반하는 삭제 E2E는 수행하지 않았다.

## 5-23. 8/13 방문 위치 인증 구현 (민서 브랜치 QA·main 반영 완료, 배포 전)

**구현**:
- 매장 상세에서 매장명만 넘기던 방문 인증 경로를 매장 객체 전체 전달로 바꿨다. 인증 화면은 기기 위치 권한·위치 서비스 상태를 확인하고 현재 좌표와 매장 좌표의 거리를 계산한다.
- 인증 반경은 50m다. 반경 안이면 위치 인증 완료 상태에서만 방문 저장 버튼이 활성화되고, 범위 밖·권한 거부·위치 서비스 해제·매장 좌표 누락은 각각 안내 후 저장을 막는다.
- 원본 GPS 좌표는 요청·DB에 저장하지 않는다. `verificationMethod=LOCATION`과 계산된 `verificationDistanceMeters`만 `POST /api/visits`에 담고, 백엔드는 LOCATION·0~50m 범위를 재검증한 뒤 Firestore 방문 기록과 응답에 저장한다.
- 방문 내역은 API 실패 시 샘플 방문 기록을 보여 주던 폴백을 제거하고 오류·다시 시도 화면으로 바꿨다. 위치 인증된 이력에는 인증 방식과 거리를 표시한다.
- 영수증은 공개 저장소/보관 정책을 마련하기 전까지 선택 UI를 노출하지 않고 `준비 중`으로 명시했다. 실제 카카오맵 외부 검색은 기존 매장 상세 경로에서 이미 동작하는 것을 확인했다.

**자동 검증**:
- 백엔드 `./gradlew test` 통과. 무인증 401, 50m 초과 400, 정상 위치 인증 저장을 포함한 VisitController 테스트를 추가했다.
- Flutter 위치 정책 단위 테스트 2건 및 전체 `flutter test` 35건 통과. 변경 Dart 파일 정적 분석은 `No issues found`.
- `flutter build web --release` 통과, `git diff --check` 통과. 전체 `flutter analyze --no-pub`의 info 42건은 기존 코드의 스타일/사용 중단 안내이며 신규 위치 인증 파일에는 없다.

**배포 전 잔여 확인**:
- 실제 모바일 또는 위치 권한을 허용한 브라우저에서 50m 이내 인증 성공, 50m 초과 차단, 권한 거부 안내를 각각 확인해야 한다. 운영 방문 데이터를 만들지 않아 라이브 방문 저장 E2E는 아직 하지 않았다.
- 현재 방식은 일반 사용자 흐름의 GPS 거리 확인이다. 위치 조작 방지 수준의 증명이 필요해지면 서버 검증 가능한 위치 증명 또는 영수증 검증을 별도 설계한다.
- 민서 브랜치 `team/minseo-pm-fe`에서 QA한 뒤 로컬 `main`에 fast-forward 반영했다. `origin/main` 푸시와 Render/Vercel 배포는 아직 하지 않았다.

## 5-24. 8/13 목업 제거 1차 (민서 브랜치 QA·main 반영 완료, 배포 전)

**제거·교체**:
- 검색 결과 화면이 매장 데이터 로드 실패나 예외 시 `$query 맛집 1호` 등 존재하지 않는 매장 3개를 생성하던 폴백을 삭제했다. 이제 실제 오류 안내와 `다시 시도`만 표시한다.
- 매장 상세 상단의 고정 `4.6 · 리뷰 128`을 `storeReviewProvider`의 실제 리뷰 개수와 평균 별점으로 교체했다. 리뷰가 없으면 지표를 표시하지 않는다.
- 매장 상세의 고정 `예상 절약 금액 2,000원` 블록을 제거했다. 실제 절약액은 방문 인증에서 사용자가 메뉴·결제 금액을 입력한 뒤 서버 계산 결과로만 확인한다.
- 공공데이터에 없는 영업시간은 꾸며진 목업/추후 개발 태그 대신 `정보 없음`으로 표시한다.
- 소셜 계정 화면의 하드코딩 카카오·Apple 이메일/연결일과 기기 메모리만 바꾸던 연결·해제·주 계정 변경 동작을 제거했다. 이제 실제 세션과 프로필에서 읽은 로그인 계정만 보여 주고, 현재 지원 범위(카카오 로그인)를 명시한다.

**검증**:
- 검색 소스가 비어 있을 때 가짜 매장 대신 오류·재시도 UI가 나오는 Flutter 위젯 테스트를 추가했다.
- 변경 화면 정적 분석은 `No issues found`로 통과했다.

**다음 목업 제거 후보**:
- 가격 알림 구독 화면의 고정 매장·메뉴와 프로필 수정의 로컬 전용 저장은 해당 API가 없어 백엔드 계약부터 필요하다.
- 영업시간은 공공데이터 원본에 값이 없으므로 별도 공급원 또는 사용자 제보 정책을 결정한 뒤 추가한다.

## 5-25. 8/13 민서 브랜치 QA 및 main 반영

**브랜치 흐름**:
- 기존 기능 브랜치의 방문 위치 인증·50m 반경 강화·목업 제거 1차 커밋을 민서 브랜치 `team/minseo-pm-fe`로 이식했다. 민서 브랜치는 기존 `main`보다 오래되어 먼저 최신 `main`으로 fast-forward했다.
- 민서 브랜치의 기능 커밋: `567eb0f` (위치 인증), `5b7c4ae` (50m 반경), `9d0d87d` (가짜 데이터 제거).
- 백엔드 `./gradlew test` 성공, Flutter 전체 테스트 35건 통과, 변경 범위 `flutter analyze --no-pub` 통과, `flutter build web --release` 성공 후 `main`에 `git merge --ff-only team/minseo-pm-fe`로 반영했다.

**현재 배포 상태**:
- 로컬 `main`은 `9d0d87d`까지 반영됐고 `origin/main`보다 3커밋 앞서 있다. 사용자의 별도 지시 전까지 GitHub push, Render 배포, Vercel production 배포는 하지 않는다.
- 실기기 위치 권한 QA는 컴퓨터 또는 실제 휴대폰 조작이 가능한 때에 50m 이내 성공·50m 초과 차단·권한 거부 안내로 진행한다.

## 5-26. 8/13 지도 내 위치 반응성 및 문의 답변 흐름 (민서 브랜치 QA·local main 반영 완료, 배포 전)

**지도 내 위치 버튼**:
- 마지막으로 확보한 위치 또는 OS 캐시 위치를 우선 사용해 버튼을 누른 즉시 지도 중심과 위치 마커를 갱신한다. 최신 고정밀 위치는 백그라운드에서 다시 가져온다.
- 버튼은 조회 중 진행 표시를 보이며, 모바일 카카오맵 중심 이동은 지연된 pan/zoom 대신 즉시 중심·레벨 설정으로 바꿨다.

**문의 답변**:
- 어드민 문의 관리에 `답변하기`·`답변 수정` 모달을 추가했다. `POST /api/admin/inquiries/{id}/answer`는 어드민 키를 검증하고 빈 답변·2000자 초과 답변을 거부한다.
- Firestore 문의 문서에 `answer`, `answeredAt`, `status=ANSWERED`를 저장한다. 답변 등록 시 해당 사용자 알림함에 `INQUIRY_ANSWER` 문서를 생성한다.
- 앱 문의 화면의 예시 입력값을 제거했고, 상단 내역 아이콘에서 `내 문의 내역` 화면으로 이동해 문의 원문·답변·시각·대기 상태를 확인할 수 있다.
- `/api/inquiry` 전체를 세션 인증 대상으로 추가해 비로그인 요청은 401로 막는다.

**웹 알림 범위**:
- 로그인한 웹 사용자는 기존 알림함과 알림 설정을 이용하고, 이번 문의 답변 알림도 알림함에서 확인할 수 있다.
- 현재는 DB 기반 인앱 알림이다. 브라우저가 닫혀 있거나 다른 탭을 보고 있어도 운영체제가 즉시 띄우는 웹 푸시는 Firebase Cloud Messaging, 서비스 워커, VAPID 키 설정이 필요하며 아직 구현하지 않았다.

**자동 검증**:
- 백엔드 `./gradlew test` 성공(문의 답변 어드민 계약·문의 인증 회귀 포함).
- Flutter 전체 테스트 38건 통과. 신규 문의·알림·라우팅 코드 정적 분석 `No issues found`.
- `flutter build web --release`, `git diff --check` 통과. 지도 화면 파일의 기존 analyzer info 12건은 이번 변경 전부터 있던 스타일 안내다.
- 민서 브랜치 `team/minseo-pm-fe`의 `bef8933`을 `git merge --ff-only`로 로컬 `main`에 반영했다. GitHub push와 Render/Vercel 배포는 사용자의 별도 지시 전까지 하지 않는다.

## 5-27. 8/13 모바일 FCM 푸시 알림 구현 (main 배포 완료·실기기 QA 대기)

**구현**:
- Flutter에 `firebase_core`, `firebase_messaging`, `flutter_local_notifications`를 추가했다. Android/iOS 네이티브에서 로그인 세션이 복원되거나 로그인되면 알림 권한을 요청하고 FCM 기기 토큰을 등록한다.
- 포그라운드 Android 알림은 로컬 시스템 알림으로 표시하며, 백그라운드 수신·알림 탭은 알림함(`/notifications`)으로 이동한다. 로그아웃 시 현재 기기 토큰을 해제한다. 웹은 기존 인앱 알림 흐름을 그대로 유지한다.
- `POST/DELETE /api/notifications/devices`를 세션 인증 API로 추가했다. FCM 토큰은 원문을 문서 ID로 노출하지 않도록 SHA-256 ID로 저장하고, 다른 사용자가 해제할 수 없게 소유자를 확인한다.
- 모든 서버 알림은 Firestore 알림함 기록을 먼저 남긴 뒤 FCM을 별도 발송한다. 만료·잘못된 토큰은 자동 정리하며, 전송 실패가 문의 답변·제보 같은 원래 작업을 실패시키지 않는다.
- 기존 알림 설정의 유형별 토글과 방해 금지 시간(Asia/Seoul)을 푸시에도 동일하게 적용했고, 회원 탈퇴 시 등록 기기 토큰도 함께 삭제한다.

**Firebase/플랫폼 설정**:
- Firebase 프로젝트 `howmuch-c7e52`에 Android `com.example.howmuch`, iOS `com.ohtaegwan.howmuch` 앱을 등록하고 FCM HTTP v1 API 활성 상태를 확인했다. `google-services.json`, `GoogleService-Info.plist`, Android Google Services 플러그인, iOS 원격 알림 entitlement·background mode를 반영했다.
- iOS CocoaPods를 정적 라이브러리+모듈 헤더 방식으로 정리해 Firebase Messaging 헤더 충돌을 해결했다.
- iOS Firebase Console에는 아직 APNs 인증 키(`.p8`/Key ID)가 등록되지 않았다. 따라서 iPhone의 실제 원격 푸시는 해당 키 등록과 실기기 수신 확인이 남아 있다.

**검증 결과**:
- Flutter 전체 `flutter test --no-pub` 38건, 변경 Dart 파일 `flutter analyze --no-pub` 통과.
- 격리된 새 Gradle 캐시에서 `NotificationControllerTest`, `FirebaseServiceUserDeletionTest`를 캐시 없이 재실행해 통과.
- `flutter build web --release --no-pub`, Android `app:assembleDebug`, iOS `flutter build ios --debug --no-codesign --no-pub` 통과. iOS 산출물은 `build/ios/iphoneos/Runner.app`이며 코드 서명은 실기기 배포 시 별도로 적용한다.

**실기기 QA 잔여**:
- Android 실제 기기에서 로그인 후 알림 권한 허용, 어드민 알림 발송, 포그라운드·백그라운드 수신과 탭 이동을 확인한다.
- iPhone은 Apple Developer APNs 인증 키를 Firebase에 등록한 후 위 시나리오를 동일하게 확인한다.

**운영 반영**:
- 커밋 `0361470`을 `origin/main`에 푸시했고 Render 자동 배포 후 `OPTIONS /api/notifications/devices`가 HTTP 200, `Allow: DELETE, POST, OPTIONS`를 반환하는 것을 확인했다. 운영 데이터는 만들거나 변경하지 않았다.

## 6. 알려진 주의사항
- Render 무료 인스턴스는 슬립/휘발성 디스크 (classpath 스냅샷이 유일한 영속 캐시)
- Firestore 쿼터: 유저 데이터(리뷰/제보/프로필/방문)만 읽음. 대량 조회 신규 추가 시 캐시 패턴 필수
- 웹에서 `debugPrint`는 릴리스 빌드에서 출력되지 않음 — QA는 Playwright로
- 토큰 절약: 작업 단위로 새 채팅, 이 문서로 상황 인계

## 5-28. 8/17 가격 변동 알림 승인 흐름 실서비스 QA

**확인 범위**:
- 운영 어드민에서 `광복절 테스트` 가격 변동 제보를 대기 목록에서 확인하고 승인했다.
- 승인 전 집계는 대기 7건·승인 4건이었고, 승인 후 대기 6건·승인 5건으로 변경됐다. 승인 완료 안내와 승인 목록 이동을 확인했다.
- QA로 생성한 제보는 승인 목록에서 `영구 삭제`해 전체 21건→20건·승인 5건→4건으로 원복했다. 첨부 사진 0장 정리 안내도 확인했다.

**가격 알림 E2E 판정**:
- 승인 로직 자체는 정상 동작했지만, 현재 로그인 계정의 가격 알림 화면에는 `착한분식`·`동네카페`·`착한미용실` 고정 매장이 표시되고 실제 찜 매장 데이터가 연결되지 않는다.
- 가격 알림 구독 저장 버튼도 현재는 성공 안내만 표시하며 서버에 매장별 구독 상태를 저장하지 않는다. 백엔드는 현재 전체 알림 설정(`GET/PUT /api/notifications/settings`)과 찜 매장명 기준 발송 로직까지만 제공한다.
- 따라서 이번 QA에서는 승인→알림 수신까지의 수신자 E2E를 정상 완료로 판정하지 않았다. 이는 승인 실패나 발송 오류가 아니라, 매장별 구독 상태를 실제 API로 연결해야 하는 구현 공백이다.

**후속 작업**:
- **구현 완료**: `GET/PUT /api/notifications/price-alerts`를 추가해 찜 문서에 매장별 `priceAlertEnabled`를 저장하고, 기존 매장명 기반 찜 문서도 호환한다.
- **구현 완료**: 공공데이터·사용자 제보 매장 응답에 이름·주소·전화번호를 정규화한 SHA-256 기반 `storeId`를 추가했다. 기존 이름 기반 ID는 조회·해제·알림 발송에서 폴백으로 지원한다.
- **구현 완료**: 가격 알림 화면의 고정 매장 3개를 제거하고 실제 찜 매장 목록·로딩·오류·빈 상태·매장별 저장 API를 연결했다. 가격 인상·인하·새 메뉴 조건도 알림 설정 문서에 저장한다.
- **운영 반영·부분 QA 완료**: `f215249`를 GitHub `main`에 push했고 Vercel 웹 `200 OK`, Render의 신규 가격 알림 API 인증 응답 `401`을 확인했다. 실계정에서 실제 찜 매장 3개가 구독 목록으로 표시되고, 현재 설정을 저장한 뒤 화면을 다시 열어도 매장별 상태가 유지되는 것을 확인했다. 알림함의 가격 변동 탭도 정상 진입했다.
- **남은 확인**: 실제 찜 매장과 같은 매장명의 승인 제보를 만들어 알림 생성·알림함 조회·읽음 처리까지 다시 실서비스 E2E로 확인한다.

**개발 검증**:
- 백엔드 `./gradlew test` 통과. 매장별 가격 알림 컨트롤러의 인증·조회·저장 테스트를 추가했다.
- `flutter analyze --no-pub`는 error 0·warning 0이며 기존 info 27건만 남았다. 가격 알림 API 집중 테스트 5건 통과, `flutter build web --release --no-pub` 성공.
- 전체 Flutter 테스트는 기존 `widget_test.dart`의 온보딩 7px overflow와 레거시 화면 실패가 남아 있다. 이번 변경으로 추가된 가격 알림 API 테스트는 별도 통과했다.

## 5-29. 8/18 오늘의 픽 거리·추천 루트 지도 보완

**수정 내용**:
- 위치가 전달된 오늘의 픽 추천에서 가까운 후보 20개를 다시 무작위 섞던 백엔드 로직을 제거했다. 이제 하버사인 거리 기준으로 후보를 가까운 순서에 맞게 유지해, 추천 1순위가 먼 매장으로 바뀌는 문제를 막는다.
- 오늘의 픽·추천 루트의 거리 표시는 1,000m 미만은 m, 이상은 소수점 한 자리 km로 통일했다. 예: `799m`, `15.8km`.
- 추천 루트 화면의 고정 지도 목업을 제거하고 카카오맵을 실제로 렌더링하도록 교체했다. 매장 마커·순번 라벨·현재 위치·추천 순서 파란 경로선을 함께 표시하며 웹과 모바일 경로를 각각 지원한다.

**운영 QA**:
- Render 백엔드 `2122e66` 배포가 `Live`로 완료된 뒤 운영 API에 대해 거리 응답 `497, 919, 966, 1278m`를 확인했다.
- Vercel `https://howmuch-zeta.vercel.app`에 `dpl_jQUpAt3HWSUig8k6Xy3qm7Jw9gsW`를 production 배포하고, 실서비스에서 오늘의 픽 거리 정렬·km 표시와 추천 루트의 실제 카카오맵·마커·현재 위치·경로선을 확인했다.

**검증 결과**:
- 백엔드 `./gradlew test` 성공.
- 거리 포맷 집중 Flutter 테스트 3건 통과.
- `flutter build web --release --no-pub` 성공, `flutter analyze --no-pub`는 error/warning 없이 기존 info 27건만 남았다.
- iOS debug 빌드는 기존 `flutter_compass-0.8.1`의 `flutter_compass-Swift.h` 누락으로 차단됐다. 이번 추천 루트 변경 코드의 오류가 아니라 iOS 의존성 환경 문제로 별도 정리가 필요하다.

## 5-30. 8/18 방문 인증 50m 안정화

**보완 내용**:
- 방문 인증 요청에 `storeId`를 함께 전달해 방문 이력과 매장 식별자가 연결되도록 보완했다.
- 방문 기록 직전에 현재 위치를 다시 확인해, 위치 인증 후 이동한 상태로 저장되는 문제를 줄였다.
- GPS 정확도가 50m를 초과하거나 유효하지 않은 경우 인증을 차단하고 재시도 안내를 표시한다.
- 기존대로 매장 거리 50m 초과, 좌표 누락, 위치 서비스 비활성화, 권한 거부 상태에서는 방문 기록을 막는다.

**검증 결과**:
- Flutter 방문 인증 정책 테스트 3건 및 전체 테스트 50건 통과.
- 백엔드 전체 `./gradlew test` 통과.
- 변경 파일 `dart analyze` 통과, 웹 릴리스 빌드 성공, `git diff --check` 통과.

**남은 실기기 QA**:
- 실제 휴대폰에서 50m 이내 성공, 50m 초과 실패, GPS 정확도 부족, 위치 권한 거부를 각각 확인해야 한다.
- 현재 인증 방식은 원본 GPS를 저장하지 않고 클라이언트가 계산한 거리와 서버의 0~50m 범위 검증을 사용한다. 위치 조작 방지 수준을 높일 필요가 생기면 별도 위치 증명 설계가 필요하다.

**브라우저 위치 에뮬레이션 QA (8/18)**:
- 실제 앱에서 `왕비집 시청무교점` 검색 → 매장 상세 → 방문 인증 화면까지 진입해 매장 좌표 전달을 확인했다.
- 같은 매장 기준 `0m` 위치에서는 위치 인증 완료·체크 표시·`방문 기록하기` 활성화를 확인했다.
- 약 `111m` 떨어진 위치에서는 거리 표시와 함께 인증 완료가 되지 않고 기록 버튼이 비활성 상태로 유지됐다.
- 위치 서비스는 켜져 있으나 권한만 거부된 상태에서는 `권한이 거부되었습니다` 안내와 기록 버튼 비활성 상태를 확인했다.
- 위 결과는 브라우저에서 위치 공급기를 에뮬레이션한 QA이며, 실제 휴대폰 GPS·권한 팝업·로그인 후 저장 성공은 실기기에서 최종 확인이 필요하다.

## 5-31. 8/18 알림함 목적지 연결 및 회귀 점검 (main push·웹 배포 완료)

**보완 내용**:
- 알림 항목을 누르면 읽음 처리만 하던 동작을 보완해, 문의 답변은 `내 문의 내역`, 가격 변동은 `가격 알림`, 제보 승인·반려는 `내 제보`, 댓글·리뷰 반응은 `커뮤니티`, 추천·오늘의 픽은 `오늘의 픽`으로 이동하도록 연결했다.
- 백엔드 원본 타입(`INQUIRY_ANSWER`, `PRICE_ALERT`, `FEED_COMMENT`, `RECOMMENDATION` 등)과 화면 표시 타입을 같은 매핑 함수로 처리해 타입 표기 차이로 목적지가 누락되지 않게 했다.
- 읽음 처리 API가 실패하면 화면 이동을 중단하고 기존 안내 메시지를 보여 준다. 공지사항처럼 연결 대상이 없는 알림은 읽음 처리 후 알림함에 남는다.

**검증 결과**:
- 알림 목적지 매핑 테스트 2개를 추가했고 관련 Flutter 테스트 7건 통과.
- Flutter 전체 테스트 52건 통과.
- 변경 파일 정적 분석 `No issues found`, `git diff --check` 통과.

**배포 결과**:
- 커밋 `fdbd316`을 `origin/main`에 push했다.
- Vercel `howmuch` 프로젝트 production 배포 `dpl_Gg7rByDL76kK9HZtdjfFrFMd1b84`가 `READY` 상태로 완료됐고, 운영 별칭 `https://howmuch-zeta.vercel.app`에서 HTTP 200을 확인했다.
- GitHub push로 Render 자동 배포가 반영됐으며, 운영 `/api/notifications`는 인증 보호에 따른 HTTP 401을 반환해 서버 기동을 확인했다.
- 로그인 계정으로 알림함에서 문의 답변·가격 변동·제보·추천 알림을 각각 눌러 실제 화면 이동과 읽음 처리를 확인하는 실사용 QA는 후속으로 진행한다.

## 5-32. 8/19~8/20 전체 안정화 감사·회귀 테스트·운영 배포 완료

**기준과 배포 상태**:
- 기준 브랜치는 `main`, 시작 HEAD와 `origin/main`은 모두 `c54b28a`였다. 팀원 원격 브랜치도 비교했으며 태관의 최신 오류 수정은 이미 `b3b246e`에서 main에 반영돼 추가 이식할 커밋이 없었다. 오래된 팀원 브랜치는 공유 파일을 되돌릴 위험이 있어 병합하지 않았다.
- 안정화 변경을 `67a6a8d`, Render 기동 복구를 `f6e201b`, 생성자 주입 복구를 `bece515`로 나눠 `origin/main`에 push했다. 운영 애플리케이션 코드와 Render 배포 기준은 `bece515`다.
- Vercel production 배포 `dpl_5bxhJThff8ypQLzTdZ3hfzjh9PNK`가 `READY`로 완료됐고 운영 별칭 `https://howmuch-zeta.vercel.app`에 연결됐다.
- Render 첫 배포는 매장 캐시 선로딩이 포트 기동을 막았고, 두 번째 배포는 테스트용 생성자가 추가된 `GeocodingService`의 운영 생성자 주입 지정 누락으로 실패했다. 캐시 워밍을 `ApplicationReadyEvent` 이후 비동기로 옮기고 운영 생성자에 `@Autowired`를 지정했다. 최종 `bece515` 배포 `dep-da3cjrjl550s738310eg`는 3분 2초 만에 성공했다.

**주요 버그 수정**:
- 인증·API: 만료·잘못된 세션은 일관된 JSON 401로 처리하고 CORS를 유지한다. 로그아웃 API 실패 시에도 로컬 토큰·푸시 토큰·프로필 상태를 정리하며 세션 만료 화면의 가짜 이메일을 제거했다. 커뮤니티·리뷰·AI·사용자 API의 null 본문, 잘못된 문서 ID, 길이 상한과 안전한 오류 응답을 보강했다.
- 영수증 OCR: JPEG/PNG/WebP 실제 시그니처와 5MB 제한, 요청 횟수 제한, Vision timeout·키 미설정·quota/provider 오류·빈 OCR 결과 폴백을 처리한다. 상호명·라벨 금액·7일 이내 날짜가 모두 일치할 때만 자동 승인하고 나머지는 관리자 검수로 보낸다. 이미지 자체 SHA-256으로 계정 간 동일 영수증 재사용을 막고 기존 사용자별 해시도 조회한다. Firestore `create`로 동시 중복을 막고 저장 실패 시 업로드 이미지를 정리한다. 앱 OCR 요청 제한은 일반 API 15초보다 긴 45초로 조정했다.
- 방문·위치: 서버가 매장 좌표로 거리를 다시 계산하고 50m 경계, GPS 정확도 50m 이하, 유효 좌표, 당일 동일 매장 중복을 검증한다. 앱은 30초가 지난 방문 인증 위치를 거부한다. 홈 지도는 2분 이내 위치 캐시만 즉시 사용하고 최신 좌표가 오면 마커와 지도 중심을 함께 갱신하며 권한·GPS·timeout 실패 안내를 표시한다.
- 오늘의 픽·추천 루트: 위치 기반 가까운 순서를 유지하고 m/km 파싱·반올림을 통일했다. KST 현재 시각에 맞는 예보 슬롯을 선택하고 늦은 밤 다음 날 예보와 API 실패 상태를 처리한다. 유효 좌표만 지도에 전달하고 1개·2개·3개 이상 경로의 경계·마커 순서를 안정화했으며 웹/모바일 카카오맵 로딩 오류와 외부 길찾기 연결을 보완했다.
- 알림·문의: 알림 응답의 빈 값·알 수 없는 유형·날짜를 안전하게 매핑하고, 읽음 실패 시 낙관적 상태를 되돌린다. 웹 미확인 알림 안내는 알림 ID 집합이 바뀔 때 갱신한다. 360px에서 긴 유형·제목·본문이 넘치지 않게 줄 제한을 적용하고 뒤로가기·모두 읽음 터치 영역을 확대했다. 문의 사진은 Cloudinary 업로드 URL 최대 3개를 서버 소유권 검증 후 저장하며 사용자 내역과 관리자 화면에서 확인할 수 있다.
- 관리자·운영: ADMIN_KEY는 상수 시간 비교, 5분 실패 제한, 문서 ID·상태·답변·반려 사유·알림 길이 검증을 거친다. 조작 가능한 `X-Forwarded-For` 첫 값 대신 프록시가 붙인 오른쪽 주소를 실패 제한 키로 사용한다. 삭제·반려·답변의 중복 클릭 방지와 확인 UI, 빈 목록·오류 상태를 보강했다. 공공데이터 Firestore 쓰기 실패가 성공 건수로 집계되던 오류를 수정했다.
- 보안·데이터: Flutter는 Firestore를 직접 사용하지 않고 Spring API만 사용한다. `firestore.rules`는 모든 클라이언트 직접 읽기·쓰기를 차단한다. 업로드 URL은 Cloudinary 소유 폴더·HTTPS를 검증하고 로그에 토큰·Vision 키·영수증 OCR 원문을 남기지 않는다. 실제 Firebase 서비스 계정과 PEM 형태 템플릿 모두 배포 JAR에서 제외했다.
- 목업 제거: 운영 화면의 dummy/mock/sample 폴백을 전수 검색했다. 실제 API 실패를 가짜 매장·리뷰·알림으로 덮는 경로는 제거됐고 오류·빈 상태·다시 시도만 남겼다. 지도 WebView의 `http://localhost`는 로컬 HTML 기준 URL이며 백엔드 목업 주소가 아니다.

**화면별 실데이터 연결 상태**:

| 화면/기능 | 데이터 경로 | 상태 |
|---|---|---|
| 홈 지도·검색·가격 이력 | `/api/stores/all`, `/bounds`, `/price-history` | 실데이터, 오류·캐시 상태 처리 |
| 리뷰·내 리뷰 | `/api/review`, `/api/review/me` | 실데이터, 빈 리뷰·중복 탭 차단 |
| 찜·가격 알림 | `/api/favorites`, `/api/notifications/price-alerts` | 실데이터 |
| 절약 대시보드·목표·내역 | `/api/savings/**` | 실데이터 |
| 커뮤니티 피드·댓글·좋아요 | `/api/community/**` | 실데이터, 가짜 댓글 제거 |
| 오늘의 픽·추천 루트 | `/api/recommendation/**` | 실데이터, Gemini 미설정 시 비-AI 경로 유지 |
| 알림함·설정·기기 토큰 | `/api/notifications/**` | 실데이터, Android 푸시 코드 확인 |
| 문의·답변·사진 | `/api/inquiry/**`, `/api/admin/inquiries/**` | 실데이터 |
| 제보·사진 | `/api/report/**` | 실데이터, Cloudinary 연동 |
| 위치·영수증 방문 인증 | `/api/visits`, `/api/visits/receipt` | 실데이터, 서버 재검증 |
| 관리자 운영 화면 | `/api/admin/**` | ADMIN_KEY 보호 실데이터 |

**추가·보완한 회귀 테스트**:
- 백엔드 Controller: 인증 실패, 잘못된 문서 ID·null 요청, 관리자 권한·rate limit, OCR 업로드·중복, 50m 방문 경계, 추천 좌표, 알림 읽음·기기 토큰, 문의 답변·사진 계약.
- 백엔드 Service: OCR 성공·실패·timeout·날짜·금액, 방문·영수증 멱등성, 문의 작성·답변 알림, Firebase 좌표, 공공데이터 저장 실패 집계, 카카오 지오코딩, 날씨, 절약 입력 검증.
- Flutter: API 실패 시 목업 미표시, 알림 매핑·중복 갱신·360px 긴 문구·빈 상태, 문의 답변·사진 URL·긴 문구, 50m·GPS 정확도·위치 신선도, 홈 위치 캐시, 영수증 이미지 시그니처·timeout, 추천 거리·가격·좌표·루트·360px 레이아웃, 리뷰 중복 제출.

**최종 자동 검증 (8/20)**:
- `./gradlew clean test bootJar`: 성공, 백엔드 128 tests / failures 0 / errors 0 / skipped 0.
- `flutter test --no-pub`: 성공, Flutter 82 tests.
- `flutter analyze --no-pub`: `No issues found`.
- `flutter build web --release --no-wasm-dry-run`: 성공, `build/web` 44MB.
- `node scripts/check_admin_html.mjs`: 내부 스크립트 2개 파싱 성공.
- `git diff --check`: 성공.
- 생성 JAR 검사: Firebase credential 파일명과 `BEGIN PRIVATE KEY` 문구 없음.
- Render와 같은 JAR을 로컬에서 실제 기동해 3.361초 만에 포트가 열린 뒤 매장 11,207개와 사용자 제보 매장 20개가 비동기로 적재되는 것을 확인했다. 잘못된 지도 범위 요청은 HTTP 400으로 응답했다.

**운영 배포 QA (8/20 최신 배포본)**:
- `https://howmuch-zeta.vercel.app`: 루트·`/login`·`/admin.html`·Flutter bootstrap·`main.dart.js` 모두 HTTP 200. SPA 딥링크와 보안 헤더(`nosniff`, frame deny, referrer/permissions policy)를 확인했다.
- Render 정상 `/api/stores/bounds`는 실제 매장 JSON과 HTTP 200, 위도 범위가 20도인 비정상 요청은 새 검증 로직에 따라 HTTP 400을 반환했다.
- Render `/api/notifications`, `/api/admin/overview`는 자격증명 없이 HTTP 401 JSON을 반환해 인증 보호와 최신 서버 기동을 확인했다.
- 로그인 후 영수증·위치·알림·문의 쓰기 흐름은 아래 수동 검증 목록대로 실제 계정·기기 QA가 남아 있다.

**아직 수동 검증이 필요한 항목**:
- 실제 로그인 후 영수증 선택 → Cloudinary 업로드 → Vision OCR → 자동 승인 또는 관리자 검수 → 방문 내역 반영 전체 E2E. 테스트용 영수증과 운영 데이터 생성이 필요해 이번 읽기 전용 QA에서는 수행하지 않았다.
- 실제 휴대폰 GPS로 50m 이내 성공·50m 초과 차단·낮은 정확도·권한 거부를 확인해야 한다. 브라우저 위치 권한은 자동 승인하지 않았다.
- 실제 로그인 계정의 알림 읽음·문의 답변·가격 변동 제보 승인 전체 E2E와 관리자 쓰기 작업은 운영 데이터 변경을 피하기 위해 수행하지 않았다.
- Android 푸시는 기존 실기기 QA 완료 상태이나 이번 변경 후 회귀 실기기 확인이 남았다. iOS 원격 푸시는 Apple Developer APNs 키 미등록으로 계속 보류한다.
- Firebase 모바일 클라이언트 키는 앱 배포 파일에 포함되는 공개 식별자다. Google/Firebase Console에서 Android package·iOS bundle·웹 referrer 및 API별 제한이 실제 적용됐는지는 콘솔에서 별도 확인한다.
- 공공데이터 스냅샷에는 원본 좌표가 `0,0`인 항목이 일부 있다. 앱·추천·방문 인증은 이를 무효 좌표로 제외하지만 원천 데이터 재지오코딩은 별도 운영 작업이다.
- 의존성 확인에서 현재 제약과 호환되지 않는 신규 버전 54개가 안내됐다. 대규모 버전 상승은 이번 안정화 범위에서 제외했으며 별도 브랜치에서 플랫폼별 회귀 빌드와 함께 진행한다.

## 5-33. 8/20 Aside 전체 QA 완료 확인 및 후속 수정

**QA 완료 여부**:
- Aside에서 실행한 `HowMuch 전체 QA 수행` 세션이 완료 상태로 종료됐고, 사용자·관리자 관점의 핵심 흐름 결과를 확인했다.
- QA 결과 기준으로 검색·지도, 매장 상세·찜, 리뷰, 절약, 오늘의 픽·추천 루트, 알림·문의, 관리자 기능을 점검했다.
- 운영 데이터 변경 위험이 있는 제보 승인, 실제 영수증 파일 OCR, 실기기 GPS 성공, 리뷰 수정·삭제, 신선한 카카오 로그인은 읽기 전용 또는 테스트 데이터 제약으로 수동 검증 보류 상태다.

**QA에서 확인된 문제와 수정**:
- 리뷰 필수 확인 항목이 텍스트를 눌러도 선택되지 않아 제출 검증에 걸릴 수 있던 문제를 전체 행 터치 방식으로 수정했다.
- 방문 인증 위치 조회가 오래 걸릴 때 `확인 중` 상태에 남던 문제를 위치 조회 8초·전체 12초 timeout과 재시도 안내로 보완했다.
- Gemini 키가 없거나 구형·만료된 경우 추천 루트가 오류 문구로 끝나지 않고 거리순 로컬 루트를 반환하도록 보완했다.
- 오늘의 픽 카드에 실제 매장 객체를 연결하고 카드 전체를 매장 상세로 이동하도록 수정했다.
- 홈 지도에서 검색 결과가 있는데 지도 범위 조회가 비어 있을 때 빈 결과 SnackBar가 중복 표시되던 문제를 제거했다.
- 카카오 프로필 이메일이 비어 있거나 `unknown`일 때 사용자 화면에 그대로 노출하지 않고 `이메일 정보 없음`으로 표시하도록 수정했다.
- 검색 필터 버튼의 전체 hit 영역과 접근성 라벨을 명시해 모바일 터치·자동화에서 필터 바텀시트가 안정적으로 열리도록 보완했다.

**회귀 검증**:
- `flutter analyze --no-pub`: 성공, `No issues found`.
- `flutter test --no-pub`: 성공, Flutter 82 tests.
- 리뷰·검색·추천 화면 집중 테스트: 성공.
- `./gradlew test`: 성공.
- `GeminiServiceTest` AI 경로 활성화·키 미설정 fallback 회귀 테스트 추가 및 성공.
- `flutter build web --release --no-wasm-dry-run`: 성공, `build/web` 생성.
- `git diff --check`: 성공.

**현재 상태**:
- 코드 기반 QA 후속 수정과 자동 회귀 검증은 완료됐다.
- 이번 변경은 아직 main push나 Render/Vercel 재배포를 수행하지 않았다.
- 실제 운영 계정으로 영수증 OCR 전체 흐름, 실기기 GPS 방문 인증, Android 푸시 회귀, 관리자 승인 작업은 별도 수동 QA가 필요하다.

## 5-34. 8/24 운영 안정성·관리자 대상 알림·보안 후속 보완

**구현 완료(배포 전 검증 기준)**:
- 관리자 특정 알림은 UID 자유입력 대신 회원 닉네임·이메일·UID 검색 결과에서 계정을 선택하게 바꿨다. 동명이인은 이메일과 UID 일부로 구분하고, 선택되지 않은 문자열은 발송할 수 없다. `audience: ALL|USER`을 서버에서 필수로 검증해 대상 누락이 전체 발송으로 바뀌는 fail-open 경로를 제거했다.
- 특정 회원은 Firestore users 문서 존재를 확인한 뒤에만 알림함 기록을 만들며, 없는 회원은 404로 돌려준다. 관리자 회원 목록 응답도 화면에 필요한 필드만 whitelist로 반환한다.
- 제보 승인·반려는 Firestore transaction으로 `PENDING` 상태에서 한 번만 처리한다. 동시 처리·새로고침 후 요청은 409로 막고, 성공 처리 시각을 남긴다.
- 주소 자동완성·좌표 행정동 변환을 서버의 `/api/locations/**` 프록시로 옮겨 Flutter 웹/앱 번들에서 카카오 REST 키를 제거했다. 공개 helper는 IP 기준 요청 수를 제한한다.
- Android cleartext 허용과 iOS 전역 ATS 해제를 제거하고 WebView 로컬 HTML 기준 URL을 HTTPS로 변경했다. 배포 빌드는 Gradle Wrapper로 test+bootJar를 반드시 실행하고 Render `/healthz` readiness probe를 추가했다.
- `mcp_toolkit`을 제품 의존성·초기화에서 제거했다. 추천 지도, 매장 정보 복사, 마이 설정, 로그인 약관 링크, 방문 내역 KST 이번 달 통계, 키보드 회피 및 커뮤니티 위치·자동 새로고침 UX도 보완했다.

**자동 검증(배포 직전)**:
- 백엔드 `./gradlew clean test bootJar`: PASS.
- Flutter `flutter analyze`: PASS, `flutter test`: 86 PASS.
- 웹 release와 iOS Simulator debug 산출물 생성: PASS.
- 관리자 HTML 스크립트 구문·대상 선택 필수 hook 검사 및 `git diff --check`: PASS.

**운영 전제·잔여 리스크**:
- Android는 아직 Firebase Console 앱 등록·고유 applicationId·release signing이 완결되지 않아 이번 iOS/web 운영 범위에 포함하지 않는다. 템플릿 Android 식별자로 배포하지 않도록 별도 출시 작업으로 관리한다.
- 과거 Git 이력에 노출된 Firebase service-account private key는 코드 변경만으로 회수할 수 없다. Firebase Console에서 해당 키를 폐기·재발급하고, 공개 원격 이력 정리 및 기존 clone/CI secret 교체를 해야 한다.
- 공유 ADMIN_KEY 방식은 개인별 역할·감사로그·MFA를 제공하지 않는다. 현재 기능은 rate limit과 명시적 대상 검증으로 위험을 줄였으나, 실서비스 확대 전 개인 관리자 인증과 감사 로그가 필요하다.

## 5-35. 8/24 iOS 지도 재발 확인·수정

- iPhone 17 Pro Simulator에서 홈 지도가 빈 화면으로 다시 재현됐다. 원인은 모바일 지도 WebView만 과거 Kakao Maps JavaScript 키와 등록되지 않은 `howmuch.local` base URL을 사용해 운영 웹과 인증 origin이 달랐던 점이다.
- 홈 지도·추천 경로 지도를 운영 웹과 동일한 공개 JavaScript 키 및 등록된 `https://howmuch-zeta.vercel.app` origin으로 통일했다. SDK 오류는 Flutter에 전달해 빈 화면 대신 오류·재시도 화면을 표시한다.
- 재빌드·설치 후 지도 타일, 현재 위치, 매장 마커를 첫 진입에서 확인했다. 캡처는 `docs/images/qa-2026-08-24/ios-home-map.png`에 보관한다.
- GitHub Actions 품질 게이트를 추가했다. 백엔드 test+bootJar, Flutter analyze+test+web release+관리자 HTML 검사, iOS Simulator build를 main push와 PR에서 실행한다.

## 5-36. 8/24 재부팅 후 운영 보완 재개

재부팅으로 중단된 작업을 이어서 Firebase 키 처리를 제외한 안정성·접근성·출시 준비 보완을 반영했다.

- 로그인 화면에서 약관·개인정보 처리방침 명시 동의 없이는 카카오 로그인을 시작하지 않도록 변경했다.
- 앱 개인정보 처리방침·약관 화면의 존재하지 않는 로그인 수단, 연락처, 결제·접속 로그 보관 문구와 가짜 외부 링크를 제거했다. 사업자명·법정 책임자·국외 이전 고지는 실제 운영 주체 정보를 확인한 뒤 별도 기입한다.
- iOS에서 사용하지 않는 마이크 권한 문구를 제거했다.
- 관리자 키는 저장 시각을 함께 저장하고 30분 후 자동 만료한다. 관리자 모달의 Escape·Tab 포커스 트랩과 이미지 키보드 접근성을 보완했다.
- 관리자·커뮤니티 Firestore 조회에 최대 500건 보호 상한을 추가하고 관리자 화면에 상한 안내를 표시했다. 대규모 운영에서는 커서 기반 페이지네이션으로 확장해야 한다.
- 처리 완료 영수증의 Cloudinary 원본 정리를 멱등화하고, 일시 실패 건을 주기적으로 재시도해 Firestore 잔여 이미지 URL이 수렴하도록 했다.
- Android는 기본 예제 applicationId와 디버그 서명으로 release가 생성되지 않도록 막고, 실제 applicationId·release keystore를 Gradle 속성/환경변수로 주입하는 구조로 정리했다. Firebase Console 등록과 키 파일은 외부 운영 절차에서 입력한다.

### 재검증 결과

- 백엔드 `test bootJar`: PASS
- Flutter `analyze`: PASS (`No issues found`)
- Flutter 테스트: PASS (86개, `All tests passed!`)
- Web release 빌드: PASS
- Android `assembleDebug`: PASS (`build/app/outputs/flutter-apk/app-debug.apk` 생성)
- iOS Simulator debug: Xcode `Runner.app` 생성 확인. 재부팅 후 의존성 재구성 과정이 길어 최종 Flutter 종료 메시지는 수집하지 못했으며, 동일 소스의 설치·지도 캡처 결과는 5-35 회귀 기록을 따른다.
- 관리자 HTML 스크립트 검사 및 `git diff --check`: PASS

Firebase 키 폐기·재발급과 Android 실서비스 applicationId/Firebase 등록은 사용자 콘솔 작업 없이는 완료 처리하지 않는다.

배포 기준 커밋: `d447a14`. Vercel canonical 배포: `dpl_7oZdiaKJoo5tGrYBcyxgN3Ze2CB5` (`https://howmuch-zeta.vercel.app`), Render `/healthz`: HTTP 200.

## 5-37. 9/1 Firestore 읽기 한도 초과·Blaze 전환 및 운영 복구

**장애 확인**:
- Firebase Console에서 Firestore 문서 읽기가 Spark 무료 일일 한도 50,000회에 도달했다. 같은 시점의 쓰기는 17회, 삭제는 1회였으며 Firestore 의존 API와 일반 사용자·관리자 화면이 실패했다.
- 시간대별 최고 사용량은 약 19,988 reads/hour로, 일반적인 사용자 조작보다 짧은 주기의 반복 조회가 만든 형태였다.
- 발표 당일 프로젝트를 Blaze 종량제로 전환했다. Blaze 전환은 이미 사용한 무료 제공량을 초기화하지 않고, 무료 제공량을 초과한 사용량부터 과금한다.

**코드상 원인**:
- 로그인된 웹 앱은 알림함 진입 여부와 무관하게 알림 목록을 10초마다 갱신한다. 브라우저 탭과 Simulator 세션마다 독립적으로 폴링한다.
- 백엔드 알림 조회는 해당 사용자의 알림 문서를 전부 읽은 뒤 메모리에서 최신순 정렬하고 최대 100개로 자른다. 따라서 누적 테스트 알림 전체가 매 요청마다 읽기 사용량으로 계산된다.
- 커뮤니티 게시글 상세는 5초마다 게시글·작성자·좋아요·알림 구독·댓글·답글을 다시 조회한다. 댓글 조회 후 답글을 별도 조회하고 작성자 프로필을 개별 조회하는 중복/N+1 패턴이 있다.
- 커뮤니티 피드는 1분마다 제보 목록과 작성자 정보를 갱신한다. 관리자 화면도 제보·영수증·리뷰·회원·댓글·문의 목록을 페이지네이션 없이 전체 조회해 QA 중 반복 진입·새로고침이 사용량을 추가했다.
- 알림 및 커뮤니티 상세 주기 조회는 8/15 병합분에서, 웹 알림 10초 간격은 8/25의 새로고침 없는 알림 보완에서 유입됐다. 초기의 화면 진입·사용자 동작 중심 조회 설계가 이후 폴링 추가로 달라진 상태다.

**Blaze 전환 직후 운영 점검**:
- 전환 직후 Vercel의 일반 화면과 관리자 화면 모두 `healthz` 준비 확인에 실패했다. `healthz`는 Firestore와 외부 서비스를 읽지 않는 단순 응답이므로 이 구간은 Firebase가 아니라 Render 무료 서버의 일시적인 기동 실패로 분리했다.
- Render 공식 상태에는 전날 Singapore 리전 서비스 불안정과 무료 서비스 유휴 기동 중단 이력이 있었고, 이후 서버가 다시 기동되면서 사용자 화면과 관리자 API가 정상화됐다.
- 복구 후 관리자 대시보드에서 회원 4명, 공공데이터 매장 11,207개, 제보 19건, 리뷰 2건, 방문 인증 8건, 찜 4건을 확인했다.
- 관리자 제보 19건, 영수증 7건(승인 5·반려 2), 리뷰 2건, 댓글·답글 2건, 문의 5건, 회원 4명의 목록이 오류 없이 조회되는 것을 확인했다.

**시연 당일 운영 방침**:
- 시연에 필요한 웹·관리자·Simulator 세션만 열고 불필요한 중복 탭을 닫는다.
- 시연 종료 후 Spark로 다시 내릴 수 있지만 같은 날 소진된 무료 제공량은 요금제 변경으로 초기화되지 않는다. 일일 제공량 초기화 전에 Spark로 내리면 Firestore 기능이 다시 차단될 수 있다.
- 코드 검색 기준 Firebase Functions·Firebase Storage 의존은 없고 이미지 저장은 Cloudinary를 사용하므로 현재 구성의 Spark 복귀 영향은 제한적이다.

**시연 후 필수 개선**:
- 전역 10초 알림 폴링을 제거하고 앱 활성·화면 표시 상태에서만 낮은 빈도로 갱신하거나 변경분 기반 방식으로 전환한다.
- 알림 서버 쿼리에 최신순 정렬과 Firestore 단계 `limit`·커서 페이지네이션을 적용한다.
- 커뮤니티 상세 5초 폴링을 제거하고 작성·좋아요·답글 동작 직후 및 사용자의 새로고침 요청 때만 갱신한다.
- 답글은 펼칠 때 조회하고 댓글/작성자 N+1 조회를 배치 또는 응답 비정규화로 줄인다.
- 커뮤니티 피드는 진입·재진입·당겨서 새로고침 중심으로 바꾸고, 관리자 전체 목록에는 서버 커서 페이지네이션을 적용한다.
- 수정 후 단일 탭·다중 탭·백그라운드 상태별 Firestore 읽기량을 측정해 회귀 기준으로 기록한다.

## 5-38. 9/1 방문 위치 인증 반경 100m 조정

- 발표 현장의 GPS 오차와 교내 건물 환경을 고려해 방문 위치 인증 반경을 기존 50m에서 100m로 조정했다.
- Flutter의 버튼 활성화 판정과 `100m 이내에서 인증할 수 있어요` 안내 문구, 제출 차단 SnackBar를 동일 기준으로 변경했다.
- 백엔드는 클라이언트가 전달한 거리값을 신뢰하지 않고 기존처럼 매장 좌표와 현재 좌표의 거리를 다시 계산하며, 서버 계산 결과가 100m를 초과하면 저장을 거부한다.
- 발표 환경에서 50m 정확도 기준으로 인한 위치 확인 실패를 줄이기 위해 GPS 측정 정확도 허용 기준도 100m 이하로 조정했다. 거리 기준과 정확도 기준은 의미가 다르므로 별도 상수 구조는 유지한다.
- Flutter의 인증 거리와 GPS 정확도 경계 테스트를 각각 100m 성공·100.1m 실패로 변경했다. 백엔드에는 약 89m 위치의 방문 저장 성공, 정확도 100m 성공·100.1m 실패 회귀 테스트를 추가하고 기존 약 111m 거리 초과 차단 테스트는 유지했다.

## 5-39. 9/1 운영 복구·100m 배포 확정 및 읽기량 최적화 착수

**운영 복구와 배포 기준**:
- Firebase 프로젝트가 Blaze 종량제로 전환된 것을 콘솔에서 확인했고, Firestore 무료 읽기 제공량 50,000회를 소진한 뒤 차단됐던 일반 사용자·관리자 데이터 조회가 정상화됐다.
- 최종 시연 버그 수정은 `1222fc2`, 방문 인증 반경 100m 변경은 `02015c8`, GPS 정확도 허용 기준 100m 변경은 `d46e279` 커밋으로 `main`에 반영됐다.
- Vercel 운영 배포 `dpl_AsvAXaVfNvmc4dpESmK2wbsJSqfC`를 `https://howmuch-zeta.vercel.app`에 연결했다. 로컬 운영 빌드와 배포된 `main.dart.js`의 SHA-256이 일치했고, Render `/healthz`도 HTTP 200을 반환했다.
- 발표용 동양미래대학교 학식당 영수증 이미지는 저장소 밖의 산출물로 생성해 Git 추적 대상에서 제외했다. 로컬에 설치한 Agent Skill 관련 `.agents/`, `.codex/`, `skills-lock.json`도 제품 코드와 분리해 커밋하지 않는다.

**현재 운영 리스크와 이번 개선 범위**:
- Blaze 전환은 즉시 서비스 복구 수단일 뿐 반복 조회 구조를 해결하지 않는다. 다중 웹 탭과 Simulator가 열린 상태에서 알림 10초, 커뮤니티 상세 5초 폴링이 계속되면 Firestore 읽기 비용이 다시 급증할 수 있다.
- 1차 개선은 알림을 앱 활성 상태의 60초 주기와 수동 갱신으로 제한하고, 커뮤니티 상세의 5초 폴링을 제거해 화면 진입·복귀·사용자 동작 직후에만 갱신하는 것이다.
- 서버는 알림 조회를 Firestore 쿼리 단계에서 최대 100건으로 제한하고, 댓글·답글 작성자 조회의 중복을 요청 단위 캐시로 줄인다. 커뮤니티 답글은 화면 진입 때 전부 불러오지 않고 필요한 시점에 조회하도록 변경한다.
- 수정 후 단일 탭·다중 탭·백그라운드에서 불필요한 주기 요청이 발생하지 않는지 테스트하고, 백엔드 전체 테스트·Flutter 테스트·정적 분석·웹 release 빌드로 회귀를 확인한다.

## 5-40. 9/2 Firestore 반복 읽기 1차 최적화 완료(로컬 검증)

**클라이언트 조회 주기 개선**:
- 웹 10초·앱 60초로 나뉘던 알림 폴링을 로그인 상태이면서 앱이 활성화된 경우에만 동작하는 공통 60초 주기로 변경했다. 백그라운드·비활성 상태와 로그아웃 상태에서는 타이머를 중지하고, 다시 활성화되면 즉시 한 번 갱신한 뒤 60초 주기를 재개한다.
- 커뮤니티 게시글 상세의 5초 폴링과 피드의 1분 폴링을 제거했다. 화면 최초 진입, 앱 복귀, 상세에서 피드로 돌아온 시점, 댓글·답글·좋아요·구독 처리 직후, 사용자의 당겨서 새로고침 동작에서만 데이터를 갱신한다.
- 상세 진입 때 댓글마다 답글 API를 호출하던 N+1 흐름을 제거했다. 답글 수만 표시하고 사용자가 `답글 N개 보기`를 선택할 때 해당 댓글의 답글만 불러오며, 로딩·접기·재시도 상태와 접근성 라벨을 제공한다.

**서버 조회량 개선**:
- 알림은 사용자 조건, `createdAt` 최신순 정렬, 최대 100건 제한을 Firestore 쿼리 단계에서 적용한다. 과거처럼 사용자 알림 전체를 읽은 뒤 서버 메모리에서 자르지 않는다.
- 최상위 댓글은 게시글·부모 없음 조건과 오래된순 정렬 후 최대 200건, 답글은 부모 댓글 조건과 오래된순 정렬 후 최대 100건만 읽는다.
- 한 응답 안에서 같은 작성자의 댓글·답글이 반복될 때 사용자 프로필을 요청 단위 캐시에 보관해 동일 UID의 중복 Firestore 읽기를 제거했다.
- 위 쿼리에 필요한 복합 인덱스를 `firestore.indexes.json`에 선언하고 `firebase.json`에 연결했다. 운영 서버 코드보다 인덱스를 먼저 배포하고 빌드 완료를 확인해야 한다.

**자동 회귀 검증**:
- Flutter 전체 테스트: 133개 PASS.
- Flutter 정적 분석: `No issues found`.
- 백엔드 전체 테스트: 155개, failures 0 / errors 0 / skipped 0.
- 백엔드 `bootJar`: PASS, 실행 JAR 80MB.
- 웹 release 빌드: PASS, `build/web` 44MB.
- 관리자 HTML 내부 스크립트 3개 파싱: PASS.
- `git diff --check`: PASS.

**배포 전 주의사항**:
- 이번 1차 최적화는 로컬 코드와 테스트까지 완료됐으며 아직 `main` 커밋·푸시와 운영 배포는 하지 않았다.
- 배포 시 Firestore 복합 인덱스를 먼저 생성하고 상태가 `Enabled`가 된 뒤 Render 서버를 반영해야 알림·댓글 조회가 인덱스 준비 중 오류를 내지 않는다.
- 관리자 대용량 목록의 커서 페이지네이션과 실제 Firestore Usage 대시보드의 배포 전후 읽기량 비교는 다음 단계로 남긴다.

## 5-41. 9/2 Firestore 인덱스·읽기 최적화 운영 배포 및 관리자 중복 조회 제거

**운영 배포 완료**:
- Firebase Console에서 알림용 `userId + createdAt`, 최상위 댓글용 `postId + parentId + createdAt`, 답글용 `parentId + createdAt` 복합 인덱스 3개를 생성했고 모두 `사용 설정됨` 상태를 확인했다.
- 읽기 최적화 커밋 `9704f06`을 GitHub `main`에 푸시했다.
- Vercel 배포 `dpl_EE47rN3KdD97EAXuhRVieaYpfjM3`를 기존 운영 주소 `https://howmuch-zeta.vercel.app`에 연결했다. 운영 `main.dart.js`와 로컬 release 빌드의 SHA-256이 일치하고 웹 HTTP 200을 확인했다.
- Render `/healthz` HTTP 200을 확인했다. 실제 운영 커뮤니티 피드는 9건, 댓글이 있는 게시글의 최상위 댓글과 답글 조회도 각각 HTTP 200을 반환해 새 복합 인덱스가 운영 쿼리에서 정상 동작함을 확인했다.

**후속 관리자 읽기량 개선**:
- 관리자 로그인 시 키 유효성 확인으로 받은 대시보드 응답을 버리지 않고 첫 화면에서 재사용해 `/api/admin/overview` 중복 요청을 제거했다.
- 수동 새로고침이 현재 메뉴와 무관하게 제보 전체 목록을 먼저 조회한 뒤 해당 화면에서 다시 조회하던 이중 요청을 제거했다. 이제 현재 화면에 필요한 API만 한 번 호출한다.
- 제보·영수증·리뷰가 0건이어도 조회 완료 여부를 별도 상태로 기억해 메뉴 재진입 때 빈 목록을 반복 조회하지 않는다.
- 제보 승인·반려, 영수증 승인, 회원·리뷰·댓글 삭제 후 영향받는 대시보드·커뮤니티 통계 캐시만 무효화한다. 기존 관리자 권한 검사, 30분 키 만료, 삭제 확인창과 오류·빈 상태는 그대로 유지한다.
- 관리자 HTML 스크립트 검사에 중복 조회 방지 회귀 조건을 추가했다. 내부 스크립트 3개 파싱, 웹 release 빌드, `git diff --check`가 통과했다.

## 5-42. 9/2 관리자 중복 조회 개선 최종 배포 확정

- 관리자 읽기량 개선 커밋 `66841a0`을 GitHub `main`에 푸시했다. 앞선 Firestore 반복 읽기 최적화 커밋 `9704f06`을 포함한 최신 운영 기준이다.
- 최종 Vercel 배포 `dpl_6oedvcFXXwsGn9MRus5a9edhVwCk`를 기존 운영 주소 `https://howmuch-zeta.vercel.app`에 연결했다. 사용자에게 노출되는 주소는 바뀌지 않았고, 배포 버전만 최신 커밋으로 교체됐다.
- 운영 `admin.html`과 로컬 웹 release 산출물의 SHA-256이 일치했으며 운영 웹은 HTTP 200을 반환했다.
- 두 번째 `main` 푸시 후 Render `/healthz`도 HTTP 200을 반환해 프론트엔드와 백엔드가 모두 정상 상태임을 확인했다.
- 로컬 작업 트리에는 제품 코드 변경이 남아 있지 않다. `.agents/`, `.codex/`, `skills-lock.json`은 로컬 Agent Skill 설정이므로 계속 Git 추적 대상에서 제외한다.

**다음 권장 작업**:
- 동일 계정으로 웹 한 탭만 열어 30~60분 동안 홈·알림·커뮤니티를 사용하고, Firebase Usage/쿼리 통계에서 시간당 읽기 증가량을 기록해 최적화 전 최고치 약 19,988 reads/hour와 비교한다.
- 운영 로그인 상태에서 알림 자동 갱신, 커뮤니티 당겨서 새로고침, 답글 지연 로딩, 관리자 새로고침을 실제 UI로 회귀 확인한다.
- 그다음 GPS 100m 방문 인증과 영수증 OCR 자동 승인·관리자 승인·반려를 한 번씩 수행해 최종 시연 경로를 고정한다.
- 운영 데이터가 수백 건 규모로 증가하기 전 관리자 목록 커서 페이지네이션을 별도 변경으로 도입한다. 현재 데이터 규모에서는 반복 요청 제거의 효과가 더 크므로 즉시 페이지네이션을 추가할 필요는 낮다.

## 5-43. 9/2 운영 UI 읽기 최적화 회귀 QA

- 알림 자동 갱신: 김민서 계정의 운영 홈 화면을 새로고침하거나 이동하지 않은 상태에서 관리자 알림을 1건 등록했다. 관리자 화면에서 `알림함 등록 완료 — 1명에게 등록됨`을 확인했고, 사용자 화면의 미읽음 표시가 발송 전 1건에서 발송 후 45초 시점 2건으로 자동 변경되어 PASS 처리했다.
- 커뮤니티 당겨서 새로고침: 운영 커뮤니티 피드에서 새로고침 후 목록이 정상 유지되고 오류·빈 화면이 발생하지 않아 PASS 처리했다.
- 답글 지연 로딩: 게시글 `QA-20260822-223202-WEB 매장 QA 메뉴 1000`(문서 ID `ClMGqMtNueiQKhRbFZzA`) 상세 진입 시 답글 본문을 먼저 불러오지 않고 `답글 1개 보기`만 노출되는 것을 확인했다. 버튼 선택 후 `QA-20260823-WEB 답글`이 로드되고 `답글 접기`로 다시 접혀 PASS 처리했다.
- 이번 검증으로 생성된 운영 잔여 데이터는 제목 `알림 자동 갱신 확인`, `알림 실시간 수신 검증`인 QA 알림 2건이다. 삭제 API를 추가하지 않고 QA 식별 가능한 상태로 유지한다.
