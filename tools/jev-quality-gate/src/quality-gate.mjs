export const MODEL_ID = 'typesafe-ai/jev';
export const MAX_STATE_LENGTH = 24000;

const sensitiveKeyPattern =
  /(authorization|cookie|credential|password|private.?key|secret|session|token)/i;

export const questions = Object.freeze({
  releaseDecision: {
    type: 'choice',
    instructions:
      '제공된 요구사항, 테스트, 정적 분석, 남은 위험을 기준으로 현재 변경의 배포 판정을 내린다.',
    criteria: {
      ready:
        '필수 품질 검증이 모두 통과했고 알려진 중대 위험이 없어 배포 가능하다.',
      needs_changes:
        '치명적으로 차단되지는 않지만 배포 전 코드, 테스트, 문서 또는 검증 보완이 필요하다.',
      blocked:
        '필수 테스트 실패, 보안·데이터 훼손 위험, 핵심 기능 회귀 또는 검증 불가로 배포를 멈춰야 한다.',
    },
  },
  riskLevel: {
    type: 'score',
    instructions:
      '사용자 영향, 데이터 정합성, 보안, 회귀 가능성을 포함한 잔여 위험을 평가한다.',
    criteria: [
      'low: 영향이 제한적이고 자동 검증이 충분하다.',
      'moderate: 배포 후 모니터링이 필요하지만 롤백이 쉽다.',
      'high: 핵심 흐름이나 데이터에 영향을 줄 수 있어 추가 검증이 필요하다.',
      'critical: 보안, 데이터 유실, 전체 서비스 장애 또는 복구 불가 가능성이 있다.',
    ],
  },
  requiresHumanReview: {
    type: 'boolean',
    instructions:
      '배포 전에 사람의 추가 판단이 필요한지 평가한다.',
    criteria: {
      true:
        '불확실성이 남았거나 보안·개인정보·데이터 변경·파괴적 작업·외부 전송과 관련된다.',
      false:
        '자동 검증이 충분하고 검증된 롤백 경로가 있으며 고위험 영역을 건드리지 않는다.',
    },
  },
  evidenceSufficient: {
    type: 'boolean',
    instructions:
      '현재 제공된 테스트·분석·수동 QA 결과만으로 배포 판정을 내리기에 근거가 충분한지 평가한다.',
    criteria: {
      true:
        '변경 범위와 직접 관련된 자동 테스트와 필요한 수동 검증 결과가 있다.',
      false:
        '필수 테스트 결과가 누락되었거나 실패·타임아웃·미실행 항목이 해소되지 않았다.',
    },
  },
});

function sanitizeValue(value, seen = new WeakSet()) {
  if (value === null || typeof value !== 'object') return value;
  if (seen.has(value)) return '[circular]';
  seen.add(value);

  if (Array.isArray(value)) {
    return value.map((item) => sanitizeValue(item, seen));
  }

  return Object.fromEntries(
    Object.entries(value).map(([key, nestedValue]) => [
      key,
      sensitiveKeyPattern.test(key)
        ? '[redacted]'
        : sanitizeValue(nestedValue, seen),
    ]),
  );
}

export function prepareState(input) {
  const sanitized = sanitizeValue(input);
  const serialized = JSON.stringify(sanitized);
  if (serialized.length > MAX_STATE_LENGTH) {
    throw new Error(
      `평가 입력은 ${MAX_STATE_LENGTH.toLocaleString('ko-KR')}자를 넘을 수 없습니다.`,
    );
  }
  return sanitized;
}

export function formatEvaluation(result) {
  return {
    model: MODEL_ID,
    evaluatedAt: new Date().toISOString(),
    answers: result.answers,
    usage: result.usage,
  };
}
