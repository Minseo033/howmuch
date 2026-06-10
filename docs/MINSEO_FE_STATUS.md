# 김민서 FE 구현 현황

마지막 업데이트: 2026-05-28

## 요약

김민서 담당 23개 화면은 Flutter 화면으로 1차 구현 완료 상태입니다. Figma MCP로 `Howmuch-` 파일의 UX Flow Map과 주요 화면 노드를 직접 확인했고, 실제 iPhone 실행 기준으로 safe area와 하단 네비게이션 잘림 문제를 반영했습니다.

## 구현 완료 화면

| 번호 | 화면 | 진입 경로 |
| --- | --- | --- |
| `1-1` | 온보딩 · 주변 착한가격업소 | 앱 최초 실행 |
| `1-2` | 온보딩 · 절약 리포트 | 온보딩 다음 |
| `1-3` | 온보딩 · 매장 제보 | 온보딩 다음 |
| `1-4` | 로그인 | 온보딩 시작하기 |
| `1-5` | 권한 설정 | 로그인 또는 둘러보기 |
| `2-1` | 홈 / 메인 지도 | 권한 설정 완료, 바텀 탭 홈 |
| `5-1` | 마이페이지 | 바텀 탭 마이 |
| `5-A` | 알림 설정 | 마이 > 알림 설정 |
| `5-B` | 가격 알림 구독 | 알림 설정 > 구독 중인 가격 알림 |
| `5-C` | 계정 관리 | 마이 > 계정 관리 |
| `5-D` | 공공데이터 출처 | 마이 > 공공데이터 출처 안내 |
| `5-E` | 문의하기 | 마이 > 문의하기 또는 공공데이터 출처 > 문의하기 |
| `5-F` | 프로필 수정 | 마이 > 프로필 수정 |
| `5-I` | 회원 탈퇴 | 계정 관리 > 회원 탈퇴 |
| `5-J` | 개인정보 처리방침 | 계정 관리 > 개인정보 처리방침 |
| `5-K` | 서비스 이용약관 | 계정 관리 > 서비스 이용약관 |
| `5-L` | 연결된 소셜 계정 | 계정 관리 > 연결된 소셜 계정 |
| `6-1` | 관리자 제보 검토 | 관리자 계정 마이 > 관리자 제보 검토 |
| `6-2` | 관리자 문의 검토 | 관리자 계정 마이 > 관리자 문의 검토 |
| `7-1` | 네트워크 오류 | 마이 > 네트워크 오류 화면 |
| `7-2` | 검색 결과 0건 | 홈 > 검색창 |
| `7-5` | 제보 삭제 확인 | 마이 > 내 제보 상태 > 골목밥상 |
| `7-6` | 세션 만료 · 재로그인 | 마이 > 세션 만료 · 재로그인 |

## 권한 및 노출 규칙

- 관리자 메뉴는 `authStateProvider.isAdmin == true`일 때만 마이페이지에 노출됩니다.
- 일반 사용자는 `관리자 제보 검토`, `관리자 문의 검토` 메뉴를 볼 수 없습니다.
- 백엔드 권한 API가 붙기 전 팀원 QA를 위해 마이페이지 하단에 `개발용 관리자 모드` 토글을 임시로 두었습니다.
- `개발용 관리자 모드`를 켜면 `isAdmin`이 true로 바뀌고 관리자 제보/문의 검토 메뉴가 노출됩니다.
- 실제 릴리즈 전에는 이 토글을 제거하고 서버 권한값만 사용해야 합니다.
- 현재는 QA 확인을 위해 네트워크 오류/세션 만료 화면 진입 행을 마이페이지 하단에 둔 상태입니다. 실제 릴리즈 전에는 오류 발생 흐름에서만 노출되도록 연결하면 됩니다.

## 실제 기능 연결 상태

- 온보딩은 화면 전환이 슬라이드처럼 이어지도록 `PageView` 기반으로 구성했습니다.
- 로그인 버튼은 로컬 인증 상태를 갱신하고 권한 설정으로 이동합니다.
- 권한 설정은 실제 permission handler 호출 주석/흐름을 유지하고, 테스트에서는 권한 채널을 mock 처리합니다.
- 홈 지도는 현재 더미 지도이며, 박지환 BE 지도/API 연동 지점에 TODO 주석을 남겼습니다.
- 홈 검색창은 `7-2 검색 결과 0건` 화면으로 이동합니다.
- 홈 지도 마커/가격표를 누르면 매장 요약 카드가 뜨고, 지도 빈 곳을 누르면 닫힙니다.
- 매장 요약 카드가 닫힌 상태와 열린 상태에 따라 현재위치/AI 추천 버튼 위치를 다르게 배치했습니다.
- 마이페이지 스크롤, 저장 버튼, 뒤로가기, 토글, 문의 사진 첨부, 제보 삭제 확인은 실제 탭 동작을 갖습니다.
- 관리자 검토 화면은 로컬 상태로 승인/반려/보완 요청/문의 답변 흐름을 검증할 수 있습니다.

## 실제 기기에서 발견한 UI 기준

- Figma 좌표만 그대로 쓰면 iPhone Dynamic Island와 홈 인디케이터 영역에서 상단/하단 UI가 잘릴 수 있습니다.
- 화면 루트는 `FigmaMobileCanvas`를 사용하고, 상단/하단 보정은 `designSafePaddingOf(context)`를 기준으로 적용했습니다.
- 바텀 네비게이션은 safe bottom을 포함한 높이로 계산해야 라벨과 아이콘이 홈 인디케이터에 겹치지 않습니다.
- sticky 저장 버튼이 있는 화면은 스크롤 콘텐츠 높이에 footer 높이와 bottom safe area를 포함해야 합니다.
- TextField 화면은 키보드가 올라올 때 레이아웃이 깨지지 않도록 스크롤 가능해야 하며, 바깥 터치로 키보드를 닫도록 처리했습니다.
- 홈 상세 카드는 첫 진입부터 보이면 안 되고, 지도 마커/가격표를 탭했을 때만 보여야 합니다.
- 홈 floating button은 상세 카드가 열렸을 때와 닫혔을 때의 위치를 별도로 계산합니다.
- 바텀 탭 전환은 `NoTransitionPage`로 처리해 화면 전체가 갈아끼워지는 느낌을 줄였습니다.

## Figma 재검수 메모

- 기준 파일: `34BwHN03UNgCIG8lz2kRzZ`
- 확인 방식: Figma MCP `get_metadata`, `get_design_context`로 섹션과 화면 노드 확인
- 직접 확인한 주요 노드: `7-1` 네트워크 오류, `7-2` 검색 결과 0건, `7-5` 제보 삭제 확인, `7-6` 세션 만료 · 재로그인
- 기존 사용자 피드백으로 조정한 부분: iPhone safe area, 바텀 네비게이션 잘림, 온보딩 상단 로고/건너뛰기 제거, 홈 floating button 위치, 알림 설정 저장 버튼, 문의 입력/키보드 처리

## 검증 명령

```bash
dart analyze lib test
flutter test
flutter build ios --release
```

## 남은 백엔드 연동 지점

- 실제 지도 SDK/API 연결
- 매장/검색/필터/가격 정보 API 연결
- 로그인 OAuth 및 관리자 권한 API 연결
- 사용자 프로필/마이페이지 통계 API 연결
- 알림 설정/가격 알림 구독 저장 API 연결
- 문의 등록 및 첨부 사진 업로드 API 연결
- 제보 삭제 API 연결
- 관리자 제보/문의 검토 API 연결
- 네트워크 오류/세션 만료 화면을 실제 예외 처리 흐름에 연결

## 코드 주석 인계

백엔드 교체가 필요한 위치에는 `TODO(박지환 BE)` 형식의 주석을 남겼습니다. 우선 확인할 파일은 아래입니다.

- `lib/features/home/presentation/screens/home_map_screen.dart`
- `lib/features/auth/presentation/screens/login_screen.dart`
- `lib/features/mypage/presentation/state/mypage_state.dart`
- `lib/features/mypage/presentation/screens/notification_settings_screen.dart`
- `lib/features/mypage/presentation/screens/price_alert_subscription_screen.dart`
- `lib/features/mypage/presentation/screens/inquiry_screen.dart`
- `lib/features/mypage/presentation/screens/profile_edit_screen.dart`
- `lib/features/mypage/presentation/screens/account_management_screen.dart`
- `lib/features/system/presentation/screens/report_delete_confirm_screen.dart`
- `lib/features/system/presentation/screens/search_empty_screen.dart`
- `lib/features/system/presentation/screens/session_expired_screen.dart`
- `lib/features/admin/presentation/state/admin_state.dart`
- `lib/features/admin/presentation/screens/admin_report_review_screen.dart`
- `lib/features/admin/presentation/screens/admin_inquiry_review_screen.dart`
