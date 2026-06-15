# Original User Request

## Initial Request — 2026-06-15T00:03:04Z

앱 전체 코드베이스(lib/features/**/*.dart)를 스캔하여, 실제 데이터 연동이 가능함에도 불구하고 하드코딩된 '목업(Mockup) 데이터'가 남아있는 화면이나 위젯을 찾아 리포트로 정리합니다.

Working directory: /Users/min/Documents/howmuch
Integrity mode: development

## Requirements

### R1. 목업 데이터 스캔
- `lib/features` 디렉토리 내의 모든 Dart 파일을 스캔하여, UI 코드 내부에 하드코딩된 임의의 문자열(String)이나 더미 데이터 객체를 찾습니다.
- 특히 Riverpod 상태(Provider)나 GoRouter의 extra 속성, 부모 위젯의 파라미터 등을 통해 실제 데이터를 넘겨받을 수 있음에도 목업 데이터가 쓰인 곳을 중점적으로 찾습니다.
- 예시 타겟: `visit_verification_screen.dart`의 '착한분식' 등.

### R2. 교체 가이드라인 리포트 작성
- 스캔된 결과를 바탕으로 `mockup_report.md` 파일을 생성합니다.
- 리포트에는 다음 내용이 반드시 포함되어야 합니다:
  1. 문제가 되는 파일의 상대 경로 및 라인 번호
  2. 현재 하드코딩된 목업 텍스트 내용
  3. 이를 실제 데이터로 교체하기 위해 연결해야 할 데이터 소스 (예: `ref.watch(provider)`, `widget.storeName` 등) 제안

### R3. 코드 무결성 유지 (핵심 목표)
- 절대 기존 기능이나 코드를 직접 수정, 변경, 삭제하지 마세요. (No code editing)
- 이 작업은 오직 '리포트용 스캔'입니다. 현재 구현된 모든 기능에 어떠한 문제도 발생하지 않도록 코드를 읽기만 해야 합니다.

## Acceptance Criteria

### 리포트 생성 검증
- [ ] 작업 디렉토리에 `mockup_report.md` 파일이 정상적으로 생성되어야 합니다.
- [ ] 리포트 내에 유저가 예시로 든 `visit_verification_screen.dart`의 '착한분식' 사례가 정확히 리스트업 되어야 합니다.
- [ ] 리포트 내에 파일 경로, 목업 내용, 교체 제안 방법이 명확하게 표 형식 또는 마크다운 리스트 형태로 구조화되어 있어야 합니다.
