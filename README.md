# Howmuch

공공데이터 기반 착한가격업소 통합 탐색 플랫폼 졸업작품 프로젝트입니다.

## 프로젝트 개요

`얼마고?`는 공공데이터 기반 착한가격업소 정보와 사용자 제보 가성비 매장 정보를 함께 제공하는 모바일 중심 탐색 서비스입니다. 사용자는 지도에서 주변 매장을 확인하고, 검색과 필터를 통해 원하는 업소를 찾으며, 제보와 리뷰를 통해 지역 가격 정보를 보완할 수 있습니다.

## 주요 기능

- 온보딩, 로그인, 권한 설정
- 홈 지도 기반 착한가격업소 탐색
- 검색, 필터, 매장 상세, 리뷰, 방문 인증
- 사용자 제보 등록 및 제보 상태 관리
- 찜한 매장, 알림, 절약 리포트
- 관리자 제보 및 문의 검토

## 개발 환경

- Flutter 3.44.0
- Dart 3.12.0
- Android SDK 36.0.0
- iOS / Android / Web 플랫폼 생성 완료

## 실행

```bash
flutter pub get
flutter run
```

웹 실행은 아래 명령을 사용합니다.

```bash
flutter run -d chrome
```

## 팀 역할

| 이름 | 역할 | 담당 |
| --- | --- | --- |
| 김민서 | PM / Front-End | 온보딩, 홈 지도, 검색, 필터, 매장 상세, 마이페이지, 관리자, 공통 예외 화면 |
| 김다나 | Front-End | 리뷰, 방문 인증, 가격 이력 |
| 오태관 | Front-End | 제보, 커뮤니티, 절약 리포트, 추천, AI 챗봇 |
| 박지환 | Back-End | API, DB, 인증, 공공데이터 연동, 관리자 데이터 처리 |

상세 화면 분담은 [docs/ROLE_ASSIGNMENT.md](docs/ROLE_ASSIGNMENT.md)를 확인합니다.

## 작업 문서

- [파일 구조](docs/FILE_STRUCTURE.md)
- [브랜치 전략](docs/BRANCH_STRATEGY.md)
- [역할분담표](docs/ROLE_ASSIGNMENT.md)
- [김민서 FE 구현 현황](docs/MINSEO_FE_STATUS.md)
- [오태관 FE 구현 현황](docs/TAEGWAN_FE_STATUS.md)

## 현재 구현 현황

마지막 정리: 2026-07-15

- **[NEW] 백엔드 Render 클라우드 24시간 무중단 배포 완료**: 기존 로컬(ngrok) 기반 테스트 환경에서 벗어나, Spring Boot 서버를 Render에 배포하여 언제든 앱/웹에서 서버와 통신할 수 있도록 인프라를 구축했습니다. (`https://howmuch-backend-1xnu.onrender.com`)
- **[NEW] Firebase & 카카오 로그인 에러 완벽 해결**: Render 배포 과정에서 발생한 Firebase Admin SDK 인증(JWT Signature) 오류와 iOS 환경의 CocoaPods(`PhaseScriptExecution`) 빌드 에러를 모두 수정하여, 정상적인 카카오 로그인 및 사용자 인증 플로우를 복구했습니다.
- **[NEW] 방학 개발 1주차 핵심 과제 반영 완료**:
  - `GET /api/report/my` 백엔드 API 개발 (제보 날짜, 진행 상태, 반려 사유 반환)
  - 내 제보 내역 V1 및 V2 화면(`my_reports_screen.dart`, `my_reports_v2_screen.dart`) 실제 백엔드 API 연동 완료 (하드코딩 제거)
  - 리뷰 작성 화면(`review_write_screen.dart`) 진입 시 이전 화면에서 전달받은 실제 매장 파라미터(매장명, 메뉴, 가격) 동적 바인딩 처리
- **[기존] 검색 및 필터 화면 UX 고도화**: 검색 화면 진입 후 텍스트 검색 시 텍스트만 지우고, 필터 적용 시 맵 화면으로 돌아갔을 때 필터 상태가 정상 유지되도록 State 분리 로직 최적화.
- **[기존] 홈 지도 UX/UI 개선 및 카카오맵 연동**: Figma 디자인 시스템에 맞춘 네비게이션 적용, iOS 환경 대응 카카오맵 브릿지 구현, GPS 기반 내 위치 기능 추가.
- 관리자 제보/문의 검토 메뉴는 `authStateProvider.isAdmin == true`일 때만 마이페이지에 노출되며, 권한 API가 붙기 전까지는 `개발용 관리자 모드` 임시 토글을 지원합니다.

## Figma 구현 회고 및 주의사항

이번 작업에서 실제 기기 확인 중 발견한 문제를 다음 작업자와 AI가 반드시 참고해야 합니다.

- Figma 시안을 보지 않고 기존 구현을 확장하면 디자인이 크게 어긋납니다. 새 화면을 만들거나 수정하기 전에 Figma MCP로 해당 화면 노드와 치수를 먼저 확인합니다.
- 모바일 앱 기준이 우선입니다. 웹 미리보기는 보조 확인용이며, 최종 판단은 iPhone 실제 구동 화면의 safe area, Dynamic Island, 홈 인디케이터, 키보드 동작까지 포함해 봅니다.
- Figma 좌표를 그대로 쓰면 iPhone 상단/하단 안전구역에서 잘릴 수 있습니다. 이 프로젝트는 `FigmaMobileCanvas.designSafePaddingOf(context)`로 상단/하단 보정값을 더해 실제 기기에서도 보이도록 맞춥니다.
- 바텀 네비게이션은 홈 인디케이터와 겹치지 않도록 `safeBottom`을 포함한 높이를 계산해야 합니다. 아이콘과 라벨은 너무 위/아래로 밀리지 않게 실제 기기에서 다시 봅니다.
- sticky 저장 버튼이 있는 화면은 버튼 높이와 하단 safe area를 스크롤 높이에 포함해야 합니다. 그렇지 않으면 마지막 내용이 버튼 뒤에 숨거나 스크롤이 막힙니다.
- 모든 세로 화면은 작은 기기에서도 접근 가능하도록 `SingleChildScrollView`와 `AlwaysScrollableScrollPhysics`를 기본으로 고려합니다.
- TextField가 있는 화면은 키보드가 올라와도 화면이 잘리지 않아야 하고, 바깥 영역을 누르면 `FocusManager.instance.primaryFocus?.unfocus()`로 키보드가 내려가야 합니다.
- TextField의 이상한 초록색 선택/커서 색이 보이면 `TextSelectionTheme`과 입력 필드 배경색을 명시적으로 맞춥니다.
- 온보딩은 화면 자체를 갈아끼우는 느낌보다 `PageView` 기반 슬라이드 전환이 맞습니다.
- 바텀 탭 전환은 새 페이지가 튀는 느낌보다 안쪽 내용만 바뀌는 느낌이 자연스럽습니다. 현재 홈/마이 탭은 `NoTransitionPage`를 사용합니다.
- 홈 지도 상세 카드가 처음부터 떠 있으면 안 됩니다. 매장 마커/가격표를 눌렀을 때만 카드가 뜨고, 빈 지도 영역을 누르면 닫혀야 합니다.
- 홈의 현재위치 버튼과 AI 추천 버튼은 상세 카드가 열렸을 때와 닫혔을 때 위치가 달라야 합니다.
- 버튼, 토글, 사진 첨부, 삭제 확인, 저장하기 같은 기능은 단순 목업으로 두지 말고 가능한 범위에서는 로컬 Riverpod 상태로 실제 동작하게 만듭니다.
- 관리자 화면은 일반 사용자에게 보이면 안 됩니다. 프론트에서는 `isAdmin` 값으로 숨기고, 백엔드 연동 후에는 서버 권한 검증도 반드시 필요합니다.
- 관리자 화면 테스트는 임시 `개발용 관리자 모드` 토글로만 합니다. 이 토글은 백엔드 권한 API가 붙으면 삭제 대상입니다.
- Figma와 다르게 임의 카드형 UI, 임의 색상, 임의 텍스트를 넣지 않습니다. 임시 데이터가 필요하면 백엔드 교체 지점을 코드 주석으로 명확히 남깁니다.

## GitHub Pages 웹 배포 가능 여부

가능합니다. Flutter Web은 정적 파일로 빌드할 수 있어서 GitHub Pages에 올릴 수 있습니다.

```bash
flutter build web --release --base-href /howmuch/
```

빌드 결과물은 `build/web`에 생성됩니다. GitHub Pages에는 보통 `gh-pages` 브랜치에 `build/web` 내용을 올리거나, GitHub Actions로 빌드 후 Pages에 배포합니다.

주의할 점:

- GitHub Pages는 웹 미리보기용입니다. 실제 iOS 권한 모달, 네이티브 사진 접근, 일부 OAuth 흐름은 iPhone 앱과 다르게 보일 수 있습니다.
- 이 프로젝트는 모바일 앱 우선이므로 최종 UI 검수는 iPhone 실제 기기에서 합니다.
- 현재 Flutter Web은 해시 URL 형태로도 확인 가능하므로 Pages 배포 후 `/howmuch/#/home` 같은 경로로 화면 확인이 가능합니다.

## AI 작업용 프로젝트 컨텍스트

팀원이 AI 도구를 사용할 때는 이 섹션을 먼저 공유합니다. AI가 프로젝트 목표, 담당 범위, 파일 구조, 브랜치 규칙을 알고 작업하도록 하기 위한 공통 기준입니다.

### 프로젝트 한 줄 설명

`얼마고?`는 공공데이터 기반 착한가격업소와 사용자 제보 가성비 매장을 지도, 검색, 리뷰, 제보, 절약 리포트, AI 추천으로 연결하는 모바일 중심 Flutter 앱입니다. Web은 부수 플랫폼으로 함께 지원합니다.

### AI에게 알려야 할 고정 정보

- 앱 이름: `얼마고?`
- 프로젝트 성격: 졸업작품 팀 프로젝트
- 우선 플랫폼: 모바일 앱 우선, Web은 보조 지원
- 프론트엔드 기술: Flutter 3.44.0, Dart 3.12.0
- 저장소: `https://github.com/Minseo033/howmuch`
- 기본 브랜치: `main`
- 작업 방식: 팀원별 브랜치에서 작업 후 Pull Request로 `main`에 병합
- 디자인 기준: Figma 화면 번호와 화면명을 기준으로 구현
- 화면 파일 위치: `lib/features/{기능}/presentation/screens/`
- 공통 위젯 위치: `lib/shared/widgets/`
- 라우팅 관리: `lib/app/app_routes.dart`, `lib/app/app_router.dart`

### 팀원별 담당 브랜치

| 팀원 | 브랜치 | 역할 |
| --- | --- | --- |
| 김민서 | `team/minseo-pm-fe` | PM + 온보딩, 홈, 검색, 매장 상세, 마이페이지, 관리자, 공통 상태 화면 |
| 김다나 | `team/dana-map-store-fe` | 리뷰, 방문 인증, 가격 이력 |
| 오태관 | `team/taegwan-community-savings-fe` | 커뮤니티, 제보, 절약 리포트, AI 추천 |
| 박지환 | `team/jihwan-backend` | API, DB, 인증, 공공데이터, 관리자 데이터 |

### 팀원별 담당 화면 요약

| 팀원 | 담당 화면 수 | 담당 범위 |
| --- | ---: | --- |
| 김민서 | 26개 | `1-1`~`1-5`, `2-1`~`2-4`, `5-1`, `5-A`~`5-F`, `5-I`~`5-L`, `6-1`~`6-2`, `7-1`, `7-2`, `7-5`, `7-6` |
| 김다나 | 10개 | `2-5`~`2-8`, `2-10`~`2-11`, `5-G`, `5-H`, `7-3`, `7-4` |
| 오태관 | 21개 | `3-1`~`3-6`, `3-A`~`3-D`, `4-1`~`4-7`, `8-1`~`8-4` |
| 박지환 | 0개 | 화면 구현 없음. 백엔드/API/DB/인증/공공데이터 연동 담당 |

상세 화면명은 [docs/ROLE_ASSIGNMENT.md](docs/ROLE_ASSIGNMENT.md)를 기준으로 합니다.

### AI 작업 규칙

- 본인 담당 화면과 관련 파일을 우선 수정합니다.
- 다른 팀원의 담당 화면을 수정해야 하면 먼저 이유를 명확히 남깁니다.
- 새 화면을 만들기보다 이미 생성된 화면 파일을 찾아 구현합니다.
- 재사용 가능한 UI는 `lib/shared/widgets/`에 공통 위젯으로 분리합니다.
- 화면 이동은 `lib/app/app_routes.dart`와 `lib/app/app_router.dart`를 함께 갱신합니다.
- Figma 기준 화면은 실제 iPhone safe area까지 확인합니다.
- 하단 네비게이션, sticky 버튼, 키보드가 있는 화면은 실제 기기에서 잘림/겹침 여부를 한 번 더 확인합니다.
- API 연동 전에는 화면 파일 안에서 임시 더미 데이터를 사용해도 됩니다.
- 임시 더미 데이터는 박지환 백엔드 연동 시 삭제할 위치에 `TODO(박지환 BE)` 주석을 남깁니다.
- 큰 패키지 추가, 폴더 구조 변경, 라우팅 방식 변경은 팀과 먼저 합의합니다.
- 작업 후 가능하면 `dart analyze lib test`와 `flutter test`를 실행합니다.
- 커밋 메시지는 `feat: 2-4 매장 상세 화면 UI 구현`처럼 작업 화면 번호를 포함합니다.

### 팀원이 처음 작업할 때

```bash
git clone https://github.com/Minseo033/howmuch.git
cd howmuch
git fetch origin
git checkout -b team/dana-map-store-fe origin/team/dana-map-store-fe
flutter pub get
```

위 예시에서 브랜치 이름만 본인 담당 브랜치로 바꿉니다.

### AI에게 붙여넣을 프롬프트 템플릿

```text
이 프로젝트는 Flutter 3.44.0 / Dart 3.12.0 기반 졸업작품 앱 `얼마고?`입니다.
모바일 앱이 우선이고 Web은 보조 플랫폼입니다.

앱의 목적은 공공데이터 기반 착한가격업소와 사용자 제보 가성비 매장을 지도, 검색, 리뷰, 제보, 절약 리포트, AI 추천으로 연결하는 것입니다.

나는 [팀원 이름]이고, 내 브랜치는 [브랜치명]입니다.
내 담당 화면은 [화면 번호와 화면명]입니다.

화면 파일은 `lib/features/{기능}/presentation/screens/` 안에 이미 만들어져 있으니 새로 만들기보다 기존 파일을 찾아 구현해 주세요.
공통 위젯은 `lib/shared/widgets/`에 분리하고, 화면 이동이 필요하면 `lib/app/app_routes.dart`와 `lib/app/app_router.dart`도 함께 확인해 주세요.

Figma 시안을 직접 확인하고 구현해 주세요. 모바일 앱 기준이 우선이며, 실제 iPhone safe area, 하단 홈 인디케이터, 키보드, 스크롤, 바텀 네비게이션 잘림 여부까지 확인해야 합니다.

API/DB/지도/OAuth 연동 전 임시 데이터는 허용하지만, 박지환 백엔드 연동 시 교체할 위치에 `TODO(박지환 BE)` 주석을 남겨 주세요.

다른 팀원의 담당 화면은 꼭 필요한 경우가 아니면 수정하지 말고, 수정이 필요하면 이유를 설명해 주세요.
작업 후 `dart analyze lib test`와 `flutter test`가 통과하도록 해 주세요.
```

### 🚨 [중요] 최신 개발 환경 설정 주의사항 (필독)

최근 클라우드 환경 도입 및 성능 개선으로 통신 방식이 변경되었습니다. **코드 풀(Pull) 후 아래 사항을 반드시 확인하세요!**

1. **백엔드(Spring Boot) Render 클라우드 전환**
   - 이제 백엔드 서버가 `https://howmuch-backend-1xnu.onrender.com` 주소에서 24시간 가동 중입니다.
   - 프론트엔드 코드 내 API 엔드포인트가 Render URL로 연결되어 있으므로, 굳이 내 PC에서 백엔드를 켜지 않아도 카카오 로그인 및 API 테스트가 가능합니다.

2. **로컬 백엔드 개발 시**
   - 만약 백엔드 코드를 수정하고 로컬 기기(아이폰 등)에서 테스트하려면, `FirebaseConfig` 설정 시 환경 변수(`FIREBASE_CREDENTIALS_BASE64` 또는 `FIREBASE_CONFIG_PATH`)가 올바르게 주입되어야 합니다.
   - 로컬 테스트가 필요할 때만 `.env`나 `ngrok`을 활용하여 연결 주소를 로컬로 변경하세요.


## 🚀 현재 프론트엔드 진행 상황 요약 (최신 업데이트)

### 1. 홈 화면 (지도)
- 카카오맵 웹뷰 연동 완료 및 11,000개 공공데이터 마커 렌더링 최적화.
- 화면 이동/축소 시 보이는 지도 영역에 맞춰 동적으로 마커 로딩.
- GPS 내 위치 권한 연동 및 마커 터치 시 인터랙션 고도화.

### 2. 제보 및 리뷰 (1주차 개발 완료)
- **제보 내역 연동**: `my_reports_v2_screen.dart`에서 `GET /api/report/my` API 데이터를 받아 검토 중/승인/반려 상태에 따른 조건부 렌더링 구현.
- **리뷰 작성 연동**: `review_write_screen.dart`에서 매장 정보를 라우팅 파라미터로 받아 실제 가게명/메뉴 자동 완성(하드코딩 제거).

### 3. 검색 화면
- 실시간 검색(Search-as-you-type) 및 현재 위치 기반 최단 거리순 정렬 기능.
- 검색 결과 카드 내 거리(`500m`) 및 주소 기반 지역 검색 지원.

### 4. 로그인 및 인증 플로우
- 백엔드 연동을 통해 카카오 로그인 인증 플로우 정상화 (무한 프로필 설정 리다이렉트 에러 픽스).

### ⏳ 향후 개발 2주차 목표
- 방문 기록 API(`GET /api/visits`) 개발 및 `visit_history_screen.dart` 연동.
- 제보 상세 화면(`report_detail_v2_screen.dart`) 내 반려 사유 및 스텝퍼 실데이터 연동.
- 리뷰 목록 평점/리뷰 수 동적 계산 적용.
