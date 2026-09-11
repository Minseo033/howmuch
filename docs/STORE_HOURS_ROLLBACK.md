# 영업시간 작업 복구 기준 — 2026-09-12

- 시작 시 원본 작업 공간: `/Users/min/Documents/howmuch`, `main`, 변경 없음.
- 시작 커밋: `fe4c441249ab5186732a14640bb2fddde01150a5`.
- 복구 태그: `checkpoint/before-store-hours-20260912`.
- 전체 Git 이력 백업: `/Users/min/Documents/졸작/howmuch-before-hours-20260912.bundle` (`git bundle verify` 성공).
- 별도 작업 공간: `/Users/min/Documents/졸작/howmuch-hours-20260912`.
- 작업 브랜치: `feature/store-hours-20260912`.
- Vercel 운영 배포 확인: `dpl_7nbFirGNXhF6DXuUEYhxsyCSZi9v`, Ready.
- 웹 복구 주소: `https://howmuch-rmdfm10p8-minseo033s-projects.vercel.app`.
- 대표 주소: `https://howmuch-zeta.vercel.app`.
- 백엔드 운영 실행 커밋은 아직 별도 확인하지 않았으며, 웹 배포 상태로 추정하지 않는다.

## 복구 방법

작업 중에는 원본 main과 운영 DB를 변경하지 않는다. 이번 영업시간 자료는 공공데이터 원본과 별도 파일로 관리한다.

통합 전에는 원본 작업 공간을 그대로 사용하면 된다. 통합 후에는 이번 변경 커밋만 `git revert`로 되돌리고 재배포한다. 이후 사용자 변경이 있을 수 있으므로 강제 reset이나 force push를 사용하지 않는다.

웹 운영을 복구할 때는 위 검증된 배포 주소로 대표 별칭을 연결하고 실제 응답 파일을 확인한다. 백엔드 롤백은 백엔드 변경의 revert 커밋을 배포한다. 이 기록은 복구 실행 지시가 아니라 사용자가 요청한 복구 기준이다.

새 세션은 이 문서와 `docs/STORE_HOURS_PILOT.md`를 먼저 확인한다. 위 이전 웹 배포는 영업시간 변경을 검증할 때까지 삭제하지 않는다.
