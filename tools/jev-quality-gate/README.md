# Jev 품질 게이트

HowMuch 변경의 테스트·수동 QA·알려진 위험을 Jev에 전달해 배포 판정을 구조화한다. 이 결과는 사람의 최종 검토를 대체하지 않는다.

## 설치

Node.js 22 이상에서 이 디렉터리의 의존성을 설치한다.

```sh
npm install
```

## 실행

Vercel AI Gateway API 키는 파일이나 명령행 인자에 저장하지 않고 현재 쉘의 환경변수로만 주입한다.

```sh
export AI_GATEWAY_API_KEY='...'
npm run evaluate -- --input examples/quality-signals.sample.json --pretty
```

파이프로 JSON을 전달해도 된다.

```sh
cat quality-signals.json | npm run evaluate -- --pretty
```

## 출력

- `releaseDecision`: `ready`, `needs_changes`, `blocked`
- `riskLevel`: 낮음부터 치명적까지의 보간 점수
- `requiresHumanReview`: 사람의 추가 검토 필요 확률
- `evidenceSufficient`: 현재 검증 근거가 충분한 확률

`token`, `secret`, `password`, `cookie`, `credential` 등의 민감한 키는 외부 요청 전 자동으로 제거된다. 코드 전체를 보내기보다 테스트 결과와 변경 요약만 전달한다.
