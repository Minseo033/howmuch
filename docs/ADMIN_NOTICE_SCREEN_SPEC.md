# Admin notice screen specification

screen: 공지사항 등록
role_access: 유효한 `X-Admin-Key`를 가진 운영 관리자. 현재는 공유 키 방식이라 관리자별 세부 역할 구분은 없다.

## Data

objects: 전체 회원 대상 공지사항
fields: 제목(필수, 100자), 내용(필수, 500자)
filters: 없음
actions: 실시간 미리보기, 전체 회원 공지 등록

## States

loading: 등록 버튼을 비활성화하고 `등록 중…`을 표시한다.
empty: 빈 제목·내용은 API를 호출하지 않고 입력 안내를 표시한다.
error: 인증 만료는 로그인 화면으로 복귀하고, 권한 거부는 기존 서버 키 안내 상태를 사용하며, 그 외 오류는 상태 메시지를 표시한다.
permission_denied: 기존 어드민 공통 `ADMIN_KEY` 미설정/불일치 상태를 사용한다.
confirmations: 전체 회원의 웹 팝업·알림함에 반영되고 기기 푸시는 발송하지 않는다는 내용을 등록 직전에 다시 확인한다.
audit_log: 공지는 회원별 `notifications` 문서와 서버 등록 로그로 남는다. 공유 관리자 키 구조상 작업자 개인 식별 감사 로그는 현재 제공하지 않는다.

## Risks

destructive_actions: 없음. 단, 등록 후 일괄 회수 기능은 없으므로 확인창에서 비가역성을 명시한다.
private_data: 공지 탭은 회원 이메일·UID를 조회하거나 표시하지 않는다.
rollback: 등록된 공지의 일괄 회수는 지원하지 않는다. 잘못 등록한 경우 정정 공지를 새로 등록해야 한다.

## Separation contract

- `POST /api/admin/notices`: 전체 회원 알림함과 웹 접속 팝업에 `notice` 유형으로 등록하며 FCM 푸시는 보내지 않는다.
- `POST /api/admin/notifications`: 전체 또는 특정 회원에게 `general` 유형의 일반 알림을 등록하고 알림 설정에 따라 FCM 푸시를 보낸다.
- 기존 `admin` 유형은 과거 공지 데이터 호환을 위해 앱에서 계속 공지사항으로 표시한다.
