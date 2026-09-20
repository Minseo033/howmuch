import assert from 'node:assert/strict';
import test from 'node:test';
import {
  MAX_STATE_LENGTH,
  prepareState,
  questions,
} from '../src/quality-gate.mjs';

test('민감한 키의 값을 외부 평가에 전송하지 않는다', () => {
  const result = prepareState({
    summary: '회귀 테스트 통과',
    nested: {
      accessToken: 'should-not-leak',
      SESSION_SECRET: 'should-not-leak',
      testCount: 42,
    },
  });

  assert.equal(result.nested.accessToken, '[redacted]');
  assert.equal(result.nested.SESSION_SECRET, '[redacted]');
  assert.equal(result.nested.testCount, 42);
});

test('입력 크기를 제한한다', () => {
  assert.throws(
    () => prepareState({ summary: 'x'.repeat(MAX_STATE_LENGTH + 1) }),
    /24,000자/,
  );
});

test('배포 판정에 필요한 구조화 질문을 모두 포함한다', () => {
  assert.deepEqual(Object.keys(questions), [
    'releaseDecision',
    'riskLevel',
    'requiresHumanReview',
    'evidenceSufficient',
  ]);
});
