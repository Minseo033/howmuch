# 파일 구조

Flutter 앱은 모바일을 1순위로 두고, 같은 코드베이스에서 Web 실행까지 가능하도록 구성한다.

```text
lib/
  main.dart
  app/                 앱 시작, 화면 경로(app_routes.dart), 라우팅(app_router.dart), 테마
  core/
    constants/         기능 플래그, 크기·카카오맵 상수
    location/          브라우저 위치(웹과 앱 분기)
    network/           API 클라이언트
    theme/             색상·디자인 토큰
    utils/             가격 표시 등 공통 함수
  shared/
    widgets/           공통 위젯(FigmaMobileCanvas, 상단·하단 바, 대화상자 등)
  features/
    auth/              로그인, 약관, 권한, 프로필 설정
    community/         제보 작성·상세, 커뮤니티 피드, 내 제보
    errors/            찜 해제 확인, 매장 정보 오류 신고
    home/              홈 지도
    mypage/            마이페이지, 알림·계정·문의
    onboarding/        온보딩
    recommendation/    오늘의 픽, 추천 루트, AI 추천
    savings/           절약 리포트, 목표 설정
    search/            검색 결과, 필터
    store/             매장 상세, 리뷰, 가격 이력, 방문 인증, 길찾기
    system/            알림함, 세션 만료, 네트워크 오류 등 시스템 화면
```

관리자 페이지는 Flutter 밖의 `web/admin.html`, 백엔드는 `howmuch_backend/`(Spring Boot)에 있다.

## 작업 규칙

- 각자 맡은 화면 파일은 `lib/features/{기능}/presentation/screens/` 안에서 수정한다.
- 공통 위젯은 `lib/shared/widgets/`에 둔다.
- 화면 경로는 `lib/app/app_routes.dart`, 실제 라우팅은 `lib/app/app_router.dart`에서 관리한다.
- API 연동, 모델, 저장소 계층이 생기면 각 feature 안에 `data/`, `domain/`, `presentation/` 순서로 확장한다.

## 담당별 주요 폴더

| 팀원 | 주요 작업 폴더 |
| --- | --- |
| 김민서 | `onboarding`, `auth`, `home`, `mypage`, `system`, 관리자 웹(`web/admin.html`) |
| 김다나 | `search`, `store`, `mypage`, `errors` |
| 오태관 | `community`, `savings`, `recommendation` |
| 박지환 | `howmuch_backend/` API·DB |
