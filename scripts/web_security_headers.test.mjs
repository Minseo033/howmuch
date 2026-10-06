import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

// CI deploys build/web, so web/vercel.json is the configuration Vercel applies.
// The repository-root copy must stay identical to avoid silent drift.
const deployed = JSON.parse(readFileSync(new URL('../web/vercel.json', import.meta.url), 'utf8'));
const rootCopy = JSON.parse(readFileSync(new URL('../vercel.json', import.meta.url), 'utf8'));

function headerValue(config, key) {
  for (const rule of config.headers ?? []) {
    if (rule.source !== '/(.*)') continue;
    for (const header of rule.headers ?? []) {
      if (header.key.toLowerCase() === key.toLowerCase()) return header.value;
    }
  }
  return undefined;
}

test('opener policy keeps the Kakao login popup observable', () => {
  // With "same-origin", a popup that navigates to kauth.kakao.com reports
  // window.closed === true, so the app cancelled real logins after 3 seconds.
  assert.equal(headerValue(deployed, 'Cross-Origin-Opener-Policy'), 'same-origin-allow-popups');
});

test('baseline security headers remain in place', () => {
  assert.equal(headerValue(deployed, 'X-Frame-Options'), 'DENY');
  assert.equal(headerValue(deployed, 'X-Content-Type-Options'), 'nosniff');
  assert.match(headerValue(deployed, 'Content-Security-Policy'), /frame-ancestors 'none'/);
});

test('entrypoints are never cached by the deployed configuration', () => {
  const entryRule = deployed.headers.find((rule) => rule.source.includes('index.html'));
  assert.ok(entryRule, 'index.html cache rule exists in web/vercel.json');
  assert.ok(entryRule.headers.some((header) => header.key === 'Cache-Control' && /no-store/.test(header.value)));
});

test('repository-root vercel.json mirrors the deployed configuration', () => {
  assert.deepEqual(rootCopy, deployed);
});

