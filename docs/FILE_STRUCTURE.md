# 파일 구조

Flutter 앱은 모바일을 1순위로 두고, 같은 코드베이스에서 Web 실행까지 가능하도록 구성한다.

```text
lib/
  app/
    howmuch_app.dart
    app_theme.dart
    app_routes.dart
    app_router.dart
  core/
    navigation/
      app_screen.dart
  shared/
    widgets/
      figma_mobile_canvas.dart
  features/
    onboarding/
    auth/
    home/
    mypage/
    admin/
    system/
```

## 작업 규칙

- 각자 맡은 화면 파일은 `lib/features/{기능}/presentation/screens/` 안에서 수정한다.
- 공통 위젯은 `lib/shared/widgets/`에 둔다.
- 화면 경로는 `lib/app/app_routes.dart`, 실제 라우팅은 `lib/app/app_router.dart`에서 관리한다.
- API 연동, 모델, 저장소 계층이 생기면 각 feature 안에 `data/`, `domain/`, `presentation/` 순서로 확장한다.
- 백엔드 연동 전까지는 각 화면 안에서 임시 더미 데이터를 사용해도 된다.

## 담당별 주요 폴더

| 팀원 | 주요 작업 폴더 |
| --- | --- |
| 김민서 | `onboarding`, `auth`, `home`, `mypage`, `admin`, `system` |
| 김다나 | `map_search`, `store`, `mypage`, `errors` |
| 오태관 | `community`, `savings`, `ai_recommendation` |
| 박지환 | 백엔드 레포 또는 서버 폴더 확정 후 API/DB 담당 |
