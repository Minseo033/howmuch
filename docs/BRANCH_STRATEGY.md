# 브랜치 전략

## 기본 흐름

1. 작업 전 `main`을 최신 상태로 맞춘다.
2. 본인 브랜치에서 작업한다.
3. 작업이 끝나면 `flutter analyze`와 `flutter test`를 실행한다.
4. GitHub에서 Pull Request를 만들고, 리뷰 후 `main`에 병합한다.

## 팀원 브랜치

| 팀원 | 브랜치 | 담당 |
| --- | --- | --- |
| 김민서 | `team/minseo-pm-fe` | PM + 온보딩, 홈, 마이페이지, 관리자, 공통 상태 |
| 김다나 | `team/dana-map-store-fe` | 검색, 필터, 매장 상세, 리뷰, 방문 인증, 가격 이력 |
| 오태관 | `team/taegwan-community-savings-fe` | 커뮤니티, 제보, 절약 리포트, AI 추천 |
| 박지환 | `team/jihwan-backend` | API, DB, 인증, 공공데이터, 관리자 데이터 |

## 커밋 메시지 예시

```text
feat: 2-4 매장 상세 화면 UI 구현
fix: 1-4 로그인 버튼 정렬 수정
docs: 역할분담표 갱신
chore: Flutter 프로젝트 구조 정리
```
