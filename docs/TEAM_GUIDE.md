# 팀 작업 가이드 (협업·AI 작업용)

> README에서 이동한 팀 남부 문서입니다. 외부 소개는 README.md 참조.
> 최신 프로젝트 상태는 [PROJECT_STATUS.md](PROJECT_STATUS.md)가 단일 기준(source of truth)입니다.

## Figma 구현 회고 및 주의사항

실제 기기 확인 중 발견한 문제들입니다. 다음 작업자와 AI가 반드시 참고하세요.

- Figma 시안을 보지 않고 기존 구현을 확장하면 디자인이 크게 어긋납니다. 새 화면을 만들거나 수정하기 전에 Figma MCP로 해당 화면 노드와 치수를 먼저 확인합니다.
- 모바일 앱 기준이 우선입니다. 웹 미리보기는 보조 확인용이며, 최종 판단은 iPhone 실제 구동 화면의 safe area, Dynamic Island, 홈 인디케이터, 키보드 동작까지 포함해 봅니다.
- Figma 좌표를 그대로 쓰면 iPhone 상단/하단 안전구역에서 잘릴 수 있습니다. 이 프로젝트는 `FigmaMobileCanvas.designSafePaddingOf(context)`로 상단/하단 보정값을 더해 실제 기기에서도 보이도록 맞춥니다.
- 바텀 네비게이션은 홈 인디케이터와 겹치지 않도록 `safeBottom`을 포함한 높이를 계산해야 합니다. 아이콘과 라벨은 너무 위/아래로 밀리지 않게 실제 기기에서 다시 봅니다.
- sticky 저장 버튼이 있는 화면은 버튼 높이와 하단 safe area를 스크롤 높이에 포함해야 합니다. 그렇지 않으면 마지막 내용이 버튼 뒤에 숨거나 스크롤이 막힙니다.
- 모든 세로 화면은 작은 기기에서도 접근 가능하도록 `SingleChildScrollView`와 `AlwaysScrollableScrollPhysics`를 기본으로 고려합니다.
- TextField가 있는 화면은 키보드가 올라와도 화면이 잘리지 않아야 하고, 바깥 영역을 누륵면 `FocusManager.instance.primaryFocus?.unfocus()`로 키보드가 날아가야 합니다.
- TextField의 이상한 초록색 선택/커서 색이 보이면 `TextSelectionTheme`과 입력 필드 배경색을 명시적으로 맞춥니다.
- 온볼딩은 화면 자체를 갈아끼우는 느낌보다 `PageView` 기반 슬라이드 전환이 맞습니다.
- 바텀 탭 전환은 새 페이지가 튀는 느낌보다 안쪽 내용만 바뀌는 느낌이 자연스럽습니다. 현재 홈/마이 탭은 `NoTransitionPage`를 사용합니다.
- 홈 지도 상세 카드가 처음부터 떠 있으면 안 됩니다. 매장 마커/가격표를 눌렀을 때만 카드가 뜨고, 빈 지도 영역을 누륵면 닫혀야 합니다.
- 홈의 현재위치 버튼과 AI 추천 버튼은 상세 카드가 열었을 때와 닫혔을 때 위치가 달라야 합니다.
- 버튼, 토글, 사진 첨부, 삭제 확인, 저장하기 같은 기능은 단순 목업으로 두지 말고 가능한 범위에서는 로컬 Riverpod 상태로 실제 동작하게 만듭니다.
- 어드민은 앱 내 화면이 아니라 웹 페이지(`web/admin.html`)로 운영합니다 (8/3 전환 결정, 앱 내 어드민 화면·개발용 토글은 8/7 제거됨). 앱에는 어드민 UI가 존재하지 않아야 합니다.
- Figma와 다르게 임의 카드형 UI, 임의 색상, 임의 텍스트를 넣지 않습니다. 임시 데이터가 필요하면 백엔드 교체 지점을 코드 주석으로 명확히 남깁니다.

## 개발 환경 설정 주의사항 (필독)

1. **백엔드(Spring Boot) Render 클라우드 전환**
   - 백엔드 서버가 `https://howmuch-backend-1xnu.onrender.com`에서 24시간 가동 중입니다.
   - 프론트엔드 코드 내 API 엔드포인트가 Render URL로 연결되어 있으므로, 굳이 내 PC에서 백엔드를 켜지 않아도 카카오 로그인 및 API 테스트가 가능합니다.

2. **로컬 백엔드 개발 시**
   - 백엔드 코드를 수정하고 로컬 기기(아이폰 등)에서 테스트하려면, `FirebaseConfig` 설정 시 환경 변수(`FIREBASE_CREDENTIALS_BASE64` 또는 `FIREBASE_CONFIG_PATH`)가 올바르게 주입되어야 합니다.
   - 로컬 테스트가 필요할 때만 `.env`나 `ngrok`을 활용하여 연결 주소를 로컬로 변경하세요.

## GitHub Pages 웹 배포 가능 여부 (참고)

가능합니다. Flutter Web은 정적 파일로 빌드할 수 있어서 GitHub Pages에 올릴 수 있습니다. (현재 프로덕션 웹 배포는 Vercel 사용 — PROJECT_STATUS 4번 참조)

```bash
flutter build web --release --base-href /howmuch/
```

주의할 점:

- GitHub Pages는 웹 미리보기용입니다. 실제 iOS 권한 모달, 네이티브 사진 접근, 일부 OAuth 흐름은 iPhone 앱과 다르게 보일 수 있습니다.
- 이 프로젝트는 모바일 앱 우선이므로 최종 UI 검수는 iPhone 실제 기기에서 합니다.

## AI 작업용 프로젝트 컨텍스트

팀원이 AI 도구를 사용할 때는 이 섹션을 먼저 공유합니다.

### AI에게 알려야 할 고정 정보

- 앱 이름: `얼마고?`
- 프로젝트 성격: 졸업작품 팀 프로젝트
- 우선 플랫폼: 모바일 앱 우선, Web은 보조 지원
- 프론트엔드 기술: Flutter 3.44.0, Dart 3.12.0
- 저장소: `https://github.com/Minseo033/howmuch`
- 기본 브랜치: `main`
- 작업 방식: 팀원별 브랜치 작업 후 **통째 머지 금지 — 신규 파일/메서드만 선별 이식** (구버전 공유 파일 롤백 방지, PROJECT_STATUS 1번 참조). main push는 PM이 모아서 진행 (push = Render 재배포 = 비용)
- 디자인 기준: Figma 화면 번호와 화멑명을 기준으로 구현
- 화면 파일 위치: `lib/features/{기능}/presentation/screens/`
- 공통 위젯 위치: `lib/shared/widgets/`
- 라우팅 관리: `lib/app/app_routes.dart`, `lib/app/app_router.dart`

### 팀원별 담당 브랜치

| 팀원 | 브랜치 | 역할 |
| --- | --- | --- |
| 김민서 | `team/minseo-pm-fe` | PM + 온볼딩, 홈, 검색, 매장 상세, 마이페이지, 관리자, 공통 상태 화면 |
| 김다나 | `team/dana-map-store-fe` | 리뷰, 방문 인증, 가격 이력 |
| 오태관 | `team/taegwan-community-savings-fe` | 커뮤니티, 제보, 절약 리포트, AI 추천 |
| 박지환 | `team/jihwan-backend` | API, DB, 인증, 공공데이터, 관리자 데이터 |

### AI 작업 규칙

- 본인 담당 화면과 관련 파일을 우선 수정합니다.
- 다른 팀원의 담당 화면을 수정해야 하면 먼저 이유를 명확히 남깁니다.
- 새 화면을 만들기보다 이미 생성된 화면 파일을 찾아 구현합니다.
- 재사용 가능한 UI는 `lib/shared/widgets/`에 공통 위젯으로 분리합니다.
- 화면 이동은 `lib/app/app_routes.dart`와 `lib/app/app_router.dart`를 함께 갱신합니다.
- Figma 기준 화면은 실제 iPhone safe area까지 확인합니다.
- 하단 네비게이션, sticky 버튼, 키보드가 있는 화면은 실제 기기에서 잘림/겹침 여부를 한 번 더 확인합니다.
- API 연동 전에는 화면 파일 안에서 임시 더미 데이터를 사용핬도 됩니다.
- 임시 더미 데이터는 박지환 백엔드 연동 시 삭제할 위치에 `TODO(박지환 BE)` 주석을 남깁니다.
- 큰 패키지 추가, 폴리 구조 변경, 라우팅 방식 변경은 팀과 먼저 합의합니다.
- 작업 후 가능하면 `flutter analyze`와 `flutter build web`을 실행합니다.
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
내 담당 화면은 [화면 번호와 화멑명]입니다.

화면 파일은 `lib/features/{기능}/presentation/screens/` 안에 이미 만들어져 있으니 새로 만들기보다 기존 파일을 찾아 구현해 주세요.
공통 위젯은 `lib/shared/widgets/`에 분리하고, 화면 이동이 필요하면 `lib/app/app_routes.dart`와 `lib/app/app_router.dart`도 함께 확인해 주세요.

Figma 시안을 직접 확인하고 구현해 주세요. 모바일 앱 기준이 우선이며, 실제 iPhone safe area, 하단 홈 인디케이터, 키보드, 스크롤, 바텀 네비게이션 잘림 여부까지 확인해야 합니다.

API/DB/지도/OAuth 연동 전 임시 데이터는 허용하지만, 박지환 백엔드 연동 시 교체할 위치에 `TODO(박지환 BE)` 주석을 남겨 주세요.

다른 팀원의 담당 화면은 꼭 필요한 경우가 아니면 수정하지 말고, 수정이 필요하면 이유를 설명해 주세요.
작업 후 `flutter analyze`와 `flutter build web`이 통과하도록 해 주세요.
```
