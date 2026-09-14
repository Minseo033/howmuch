# 졸업작품 중간발표 1차 실서비스 QA

- 점검일: 2026-09-14
- 대상: `https://howmuch-zeta.vercel.app` 및 운영 관리자 화면
- 계정: 실제 카카오 로그인 계정(개인식별정보·비밀번호는 문서에 기록하지 않음)
- 제외: 게스트 로그인 전 과정
- 기준: 중간발표에서 시연 실패·신뢰 하락 가능성이 큰 항목을 우선순위로 분류

## 한눈에 보는 결론

자동 테스트 220개는 모두 통과했지만, 실서비스와 작은 화면에서는 발표를 막을 수 있는 문제가 확인됐다. 발표 전에 최소한 아래 7개를 정리해야 한다.

1. AI 채팅 운영 연결 복구 및 요청 개수 준수
2. AI 추천 결과의 지도 마커/목록 연결
3. 개인정보처리방침 4·6번 본문 및 목차 이동 복구
4. 길찾기 거리 라벨 실제 계산
5. 가격 알림 마지막 조건 가림 해소
6. 오늘의 픽 원거리 추천·구간 시간 불일치 수정
7. 운영 화면의 과거 QA/테스트 데이터 정리

## 점검 범위와 증거

### 실행함

- 실제 카카오 로그인과 사용자 프로필 로드
- 홈 지도, 검색, 검색 결과, 매장 상세, 길찾기
- 오늘의 픽, 추천 동선, AI 추천 채팅
- 동네제보 피드, 제보·문의·목표 입력의 빈 값 검증
- 마이페이지, 알림함, 알림 설정, 가격 알림, 계정 관리, 개인정보처리방침, 이용약관
- 관리자 대시보드, 회원·제보·영수증·리뷰·댓글·문의·공지·알림 메뉴
- 관리자에서 본인에게 일반 알림 1건 발송 후 실시간 배너와 알림함 저장 확인
- 320×568 세로 및 568×320 가로 화면 실렌더 확인
- Flutter 전체 자동 테스트 220개
- 운영 API/웹 기본 스모크 점검

### 실행하지 않음

- 게스트 로그인 전 과정
- 실제 리뷰·댓글·문의·가격제보 추가 생성
- 기존 운영 리뷰·댓글·제보·문의 삭제 또는 승인/반려
- 실제 위치를 전송하는 방문 인증과 외부 지도 앱 최종 실행
- 회원 탈퇴, 로그아웃, 마케팅 수신 동의 변경
- iOS/Android 실기기 권한 및 50m 방문 인증 경계값

## 발표 우선순위

| 우선순위 | 화면/기능 | 결과 | 증거 | 발표 영향 | 권장 조치 |
| :-- | :-- | :-- | :-- | :-- | :-- |
| P0 | AI 추천 채팅 | FAIL | 실서비스·source | 실제 AI 대신 폴백이 노출되고 “2곳” 요청에 3곳 반환 | 운영 `GEMINI_API_KEY`·모델 엔드포인트 확인, 폴백 수량 파싱 |
| P0 | AI 추천 → 지도에서 찾기 | FAIL | 실서비스·screenshot·source | 버튼을 눌러도 추천 매장 마커/목록이 표시되지 않음 | 추천 매장 ID/좌표를 홈으로 반환하고 지도 상태 갱신 |
| P0 | 개인정보처리방침 | FAIL | 실서비스·screenshot·source | 목차 4·6번은 있지만 본문이 없고 잘못된 장으로 이동 | 4·6번 본문 추가, 고정 오프셋 제거, 전체 1~7 렌더 테스트 |
| P0 | 길찾기 거리 | FAIL | 실서비스·screenshot·source | 매장마다 `거리 정보 확인 중`이 영구 표시 | 좌표로 거리 계산 후 포맷, 화면 자체 보정 추가 |
| P0 | 가격 알림 구독 | FAIL | 실서비스·screenshot·source | 마지막 `새 메뉴 등록` 스위치가 저장 버튼 뒤에 가려짐 | 절대 높이 대신 유동 스크롤과 footer 하단 패딩 적용 |
| P0 | 오늘의 픽 동선 | FAIL | 실서비스·source | 22.4km 매장 앞에 `도보 약 3분` 표시, 4번째 추천 이유 누락 | 구간 인덱스 수정, 4개 설명 일치, 최대 반경 정책 추가 |
| P0 | 운영 데이터 정리 | FAIL | 실서비스 | QA 제목·테스트 공지·샘플 제보/문의가 사용자·관리자 화면에 다수 노출 | 백업 후 명확한 QA 데이터만 선별 정리 |
| P1 | 320px 홈 지도 | FAIL | screenshot·source | 검색창·필터·오늘의 픽이 좌우로 잘려 조작과 정보 확인이 어려움 | `FigmaMobileCanvas` 320px 회귀 테스트와 폭 기반 재배치 |
| P1 | 가로 화면 | DEGRADED | screenshot·source | 고정 헤더·알림 배너·하단 CTA가 콘텐츠 면적을 크게 잠식 | 568×320 전용 높이 대응 및 배너/고정 푸터 정책 보완 |
| P1 | 알림 배너 닫기 | INTERMITTENT | screenshot·Manual | 가로 화면에서 닫은 뒤 회색 레이어가 화면 일부를 가렸고 새로고침 후 복구 | 배너 제거 애니메이션/CanvasKit repaint 재현 테스트 |
| P2 | 정책 문구 | FAIL | 실서비스·screenshot·source | 3번 본문이 `에 따라…관계 법령` 순서로 렌더되고 복사 문구에는 옛 이름 `얼마에요`가 남아 있음 | `관계 법령에 따라` 문장 조립 수정, 복사 문구를 `얼마고?`로 통일 |
| P2 | 검색 결과 의미 전달 | DEGRADED | 실서비스 | 검색어와 다른 대표 메뉴가 카드에 먼저 보여 결과가 엉뚱해 보일 수 있음 | 매칭된 메뉴를 우선 표시하고 검색어 강조 |
| P2 | 가격 제보 화면 | DEGRADED | 실서비스 | 음식점에서도 기본 메뉴가 `아메리카노`로 보이는 등 맥락 불일치 | 선택 매장 실제 메뉴를 기본값으로 연결 |
| P3 | 마이페이지 초기 로드 | DEGRADED | 실서비스 | 실제 값이 오기 전에 0원·0곳이 잠깐 보임 | skeleton 또는 로딩 상태로 대체 |

`P0`는 일반적인 장애 등급이 아니라 **다음 주 중간발표 기준 발표 차단 우선순위**다.

## 주요 실패 재현

### 1. AI 채팅이 실제 AI 대신 고정 폴백으로 동작

1. 홈에서 `AI 추천받기` 진입
2. `안중읍에서 1만원 이하 혼밥 메뉴 2곳만 추천해줘` 입력
3. 응답 첫 문장이 `AI 연결이 원활하지 않아 가까운 매장을 먼저 추천할게요.`로 표시
4. 요청한 2곳이 아니라 3곳 반환
5. 가격도 `4900`, `5000`, `6000`처럼 통화 단위/천 단위 구분 없이 표시

코드 근거:

- `lib/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart:105`
- `lib/features/recommendation/presentation/state/ai_chat_service.dart:76`
- `lib/features/recommendation/presentation/state/ai_chat_service.dart:85`
- `howmuch_backend/src/main/java/com/howmuch/service/GeminiService.java:40`
- `howmuch_backend/src/main/java/com/howmuch/service/GeminiService.java:69`

폴백은 사용자 문장에서 개수를 읽지 않고 `limit: 3`으로 고정한다. 운영 Gemini 실패 원인은 환경변수 미설정·키/쿼터·구형 후보 모델 엔드포인트·타임아웃 중 하나일 수 있으므로 배포 로그로 확정해야 한다.

### 2. `지도에서 찾기`가 사실상 뒤로가기

1. 위 AI 답변에서 `지도에서 찾기` 선택
2. 홈 지도로 돌아옴
3. 추천한 매장 3개의 마커, 강조, 결과 목록이 없음

코드 근거:

- `lib/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart:779`
- `lib/features/recommendation/presentation/screens/ai_recommend_chat_screen.dart:899`
- `lib/features/home/presentation/screens/home_map_screen.dart:1558`

버튼은 `context.pop()`만 수행하고, 채팅 메시지도 텍스트만 저장한다. 홈 화면은 추천 매장 ID나 좌표를 받을 상태와 반환값 처리 로직이 없다.

### 3. 개인정보처리방침 누락 및 목차 오작동

1. 마이 → 계정 설정 → 개인정보 처리방침
2. 목차는 1~7번 모두 표시
3. 본문은 1·2·3·5·7만 표시
4. 목차 4번을 누르면 5번 `위치 정보 처리`로 이동
5. 같은 구조로 6번은 7번 위치를 공유

코드 근거:

- `lib/features/mypage/presentation/screens/privacy_policy_screen.dart:45`
- `lib/features/mypage/presentation/screens/privacy_policy_screen.dart:83`
- `lib/features/mypage/presentation/screens/privacy_policy_screen.dart:208`
- `docs/PRIVACY_POLICY_DRAFT.md:120`

### 4. 길찾기 거리 상태가 끝나지 않음

1. 검색 결과에서 매장 상세 진입
2. 하단 `길찾기` 선택
3. `거리 정보 확인 중`이 표시되고 갱신되지 않음

코드 근거:

- `lib/features/store/presentation/screens/store_detail_screen.dart:57`
- `lib/features/store/presentation/screens/store_detail_screen.dart:65`
- `lib/features/store/presentation/screens/directions_external_app_screen.dart:264`

상세 화면이 문구를 하드코딩해 넘기고 길찾기 화면은 받은 문자열을 그대로 그린다.

### 5. 가격 알림의 마지막 조건이 고정 푸터 뒤에 가림

1. 마이 → 알림 설정 → 구독 중인 가격 알림
2. 화면 끝까지 스크롤
3. `새 메뉴 등록` 스위치와 카드 하단이 `설정 저장` 버튼 뒤에 가림

코드 근거:

- `lib/features/mypage/presentation/screens/price_alert_subscription_screen.dart:90`
- `lib/features/mypage/presentation/screens/price_alert_subscription_screen.dart:125`
- `lib/features/mypage/presentation/screens/price_alert_subscription_screen.dart:228`

스크롤 콘텐츠 높이는 실제 마지막 카드 바닥보다 약 25px 짧다.

### 6. 오늘의 픽 구간 계산·개수 불일치

- 프론트 연결선은 현재 카드의 `idx`로 `_legDistanceMeters(idx)`를 읽어 한 구간씩 밀린다.
- 백엔드는 최대 4곳을 선택하지만 Gemini 프롬프트와 로컬 설명은 최대 3곳만 만든다.
- 대안 테마 후보는 최대 거리 제한이 없어 원거리 4번째 매장이 들어올 수 있다.

코드 근거:

- `lib/features/recommendation/presentation/screens/optimal_route_screen.dart:407`
- `lib/features/recommendation/presentation/screens/optimal_route_screen.dart:419`
- `howmuch_backend/src/main/java/com/howmuch/service/GeminiService.java:192`
- `howmuch_backend/src/main/java/com/howmuch/service/GeminiService.java:224`
- `howmuch_backend/src/main/java/com/howmuch/service/FirebaseService.java:2500`
- `howmuch_backend/src/main/java/com/howmuch/service/FirebaseService.java:2555`

## 통과한 핵심 흐름

| 화면/기능 | 결과 | 비고 |
| :-- | :-- | :-- |
| 실제 카카오 로그인·세션 복원 | PASS | 실제 사용자 프로필·활동 수치 로드 |
| 홈 지도와 검색 | PASS | `김치찌개` 100건 검색, 빈 검색 기록/결과 상태 확인 |
| 매장 상세 기본 정보 | PASS | 메뉴·가격·주소·전화·영업시간 빈 상태 표시 |
| 매장 상세 320px 하단 버튼 | PASS | 전화·가격 제보·방문 인증·길찾기 4개 버튼 표시 |
| 관리자 로그인·메뉴 진입 | PASS | 대시보드 및 8개 관리 메뉴 로드 |
| 관리자 회원 검색·상세 | PASS | 실제 사용자 활동 요약과 앱 수치 정합 |
| 특정 회원 알림 발송 | PASS | 관리자 성공 메시지, 사용자 실시간 배너, 알림함 최상단 저장 |
| 입력값 방어 | PASS | 빈 제보·빈 문의·0원 목표 저장 차단 |
| 알림 클릭 이동 | PASS | 새 댓글 알림에서 커뮤니티 화면으로 이동 |
| Flutter 자동 테스트 | PASS | 220/220 통과 |
| 운영 웹·백엔드 기본 응답 | PASS | 웹/백엔드 200, 오늘의 픽·날씨 응답 |

## 현재 테스트 공백

- 주요 화면의 320×568 및 568×320 위젯 회귀 테스트가 없다.
- 개인정보처리방침 테스트는 화면 제목과 헤더 정렬만 확인해 4·6번 누락을 잡지 못한다.
- 추천 동선 테스트는 4개 매장, 구간 거리와 시간의 정합성을 검증하지 않는다.
- 길찾기 화면 테스트는 URL 정책만 확인하고 거리 라벨의 완료 상태를 검증하지 않는다.
- 가격 알림 테스트는 내부 매장 목록만 스크롤하며 마지막 조건 카드와 고정 푸터 겹침을 확인하지 않는다.
- 이미지 404·CORS 실패 시 매장 상세 대체 이미지 회귀 테스트가 없다.

최소 추가 파일: `test/responsive_viewport_smoke_test.dart`

필수 행렬:

```dart
const targetViewports = [
  Size(320, 568),
  Size(568, 320),
];
```

## 발표 전 담당 제안

### 김민서 — 통합 QA·발표 시나리오·최종 승인

- 수정본 실서비스 재검증
- 실제 카카오 로그인 → 홈 → 검색 → 상세 → 길찾기 → 오늘의 픽 → AI 추천의 발표 동선 점검
- 관리자 로그인 → 회원 조회 → 제보/문의 상태 → 본인 알림 발송 점검
- 운영 QA 데이터 정리 대상을 확정하고 삭제 전 백업·목록 승인
- 320×568, 390×844, 568×320에서 최종 시각 확인

### 오태관 — 사용자 앱 프론트엔드·UI/UX

- `FigmaMobileCanvas` 320px/가로 화면 대응
- 개인정보처리방침 4·6번, 목차 이동, 문구·고정 높이 수정
- 가격 알림 마지막 조건과 고정 저장 버튼 겹침 수정
- 길찾기 거리 라벨 표시 및 작은 화면 배치 수정
- 오늘의 픽 구간 인덱스와 4번째 범례/설명 표시 수정
- AI 추천 결과를 홈 지도 마커/목록으로 연결
- 위 항목의 위젯·반응형 회귀 테스트 추가

### 박지환 — 백엔드·운영 안정성·데이터

- Render의 Gemini 환경변수·응답 상태·실패 로그 확인
- AI 채팅 요청 개수와 응답 매장 수 계약 정리
- 오늘의 픽 최대 반경과 대안 테마 원거리 혼입 방지
- 추천 4곳과 AI 설명 4곳의 개수 일치
- 운영 QA 데이터의 안전한 선별 삭제 도구/절차 준비
- 인증·알림·관리자 API 회귀 테스트와 배포 상태 확인

김다나는 이번 역할 배정에서 제외한다.

## 권장 수정 순서

1. 박지환: Gemini 운영 연결 원인 확인 → 오태관: AI 폴백 개수·지도 연결 수정
2. 오태관: 개인정보처리방침·길찾기·가격 알림 3건 수정
3. 박지환: 오늘의 픽 반경·4개 계약 수정 → 오태관: 구간 인덱스 수정
4. 김민서: 운영 QA 데이터 삭제 목록 확정 후 정리
5. 세 명: 320×568·390×844·568×320 회귀 → 발표 시나리오 리허설

## 개인정보 및 데이터 안전 메모

- 보고서에는 실제 이메일, 인증 토큰, 관리자 비밀번호를 기록하지 않았다.
- 관리자 알림은 본인 계정에만 1건 전송했다.
- 운영 데이터 삭제·승인·반려는 수행하지 않았다.
- 위치 기반 최종 동작과 외부 지도 앱 실행은 수행하지 않았다.

## 1차 QA 후 수정 결과

- P0 7건의 코드 보완을 완료했다: AI 요청 개수·예산·지도 연결, 정책 1~7장, 길찾기 거리, 가격 알림 가림, 오늘의 픽 구간·반경, 운영 QA 데이터 정리.
- P1/P2/P3의 320px·가로 화면, 알림 배너 repaint, 정책 문구, 검색 매칭 메뉴, 가격 제보 메뉴, 마이페이지 초기 0 표시를 함께 수정했다.
- Terra High 최종 검토에서 발견한 AI 전역 매장 목록 미동기화와 성공 응답 개수·예산 불강제를 추가 보완했다.
- Luna High 관리자 검토에서 발견한 문의 첨부 이미지 소유자 누락과 내부 문서 부분 삭제 위험을 보완했다. 소유자가 없으면 삭제를 중단하며, 문의와 답변 알림은 batch로 함께 삭제한다.
- 운영 브라우저에서 알림 배너 닫기 직후 Kakao 지도 위에 회색 레이어가 남는 현상을 재현했다. 지도와 배너를 감싸는 최상위 구조 및 Material 합성 레이어를 유지하고, 숨김 상태에서는 입력·접근성을 차단한 채 배너를 화면 밖으로 이동하도록 바꿔 CanvasKit/HtmlElementView 합성 회귀를 차단했다.
- Render 자동 배포 실패 로그에서 `GeminiService` 다중 생성자 선택 실패를 확인했다. 설정값을 받는 생성자에 Spring 주입 대상을 명시하고 독립 컨텍스트 회귀 테스트를 추가해 서버 기동 차단 원인을 제거했다.
- 자동 검증 결과: Flutter 284/284, 백엔드 전체, Dart 정적 분석, 관리자 내부 스크립트 파싱, 웹 release 빌드 통과.
- 운영 QA 데이터는 명시적 제보 9건·리뷰 1건·댓글 2건을 삭제했고, 테스트 문의 3건은 새 관리자 API 배포 후 삭제한다.
