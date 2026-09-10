import assert from 'node:assert/strict';
import { mkdir, mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import test from 'node:test';
import { releaseFiles, verifyWebDeployment } from './verify_web_deployment.mjs';

async function fixture(t) {
  const buildDir = await mkdtemp(join(tmpdir(), 'howmuch-deploy-test-'));
  t.after(() => rm(buildDir, { recursive: true, force: true }));
  const files = new Map(releaseFiles.map((file) => [file, `release content: ${file}`]));
  await Promise.all([...files].map(async ([file, body]) => {
    await mkdir(dirname(join(buildDir, file)), { recursive: true });
    await writeFile(join(buildDir, file), body);
  }));
  return { buildDir, files };
}

test('matching assets and SPA entry points pass', async (t) => {
  const { buildDir, files } = await fixture(t);
  const results = await verifyWebDeployment({ buildDir, fetchImpl: async (url, options) => {
    assert.equal(options.redirect, 'manual');
    return new Response(files.get(url.pathname.slice(1)) ?? files.get('index.html'));
  } });
  assert.equal(results.length, releaseFiles.length + 3);
  assert.ok(results.every((result) => result.ok));
});

test('stale app, SPA fallback for a missing script, and broken deep link fail despite HTTP 200', async (t) => {
  const { buildDir, files } = await fixture(t);
  const results = await verifyWebDeployment({ buildDir, fetchImpl: async (url) => {
    if (url.pathname === '/main.dart.js') return new Response('old release');
    if (url.pathname === '/flutter_bootstrap.js') return new Response(files.get('index.html'));
    if (url.pathname === '/home') return new Response('not the app');
    if (url.pathname.endsWith('.ttf')) return new Response(files.get('index.html'));
    return new Response(files.get(url.pathname.slice(1)) ?? files.get('index.html'));
  } });
  assert.deepEqual(results.filter((r) => !r.ok).map((r) => r.path), [
    'main.dart.js', 'flutter_bootstrap.js', 'assets/assets/fonts/NotoSansKR-Variable.ttf', '/home',
  ]);
});

test('authentication redirect and timeout are failures and other checks still run', async (t) => {
  const { buildDir, files } = await fixture(t);
  const results = await verifyWebDeployment({ buildDir, fetchImpl: async (url) => {
    if (url.pathname === '/admin.html') return new Response(null, {
      status: 302, headers: { Location: 'https://example.com/login?token=secret' },
    });
    if (url.pathname === '/main.dart.js') throw new DOMException('timeout', 'TimeoutError');
    return new Response(files.get(url.pathname.slice(1)) ?? files.get('index.html'));
  } });
  assert.equal(results.filter((r) => !r.ok).length, 2);
  assert.equal(results.at(-1).ok, true);
  assert.ok(!JSON.stringify(results).includes('secret'));
});

test('missing local build fails before any network request', async (t) => {
  const { buildDir } = await fixture(t);
  await rm(join(buildDir, 'main.dart.js'));
  let requests = 0;
  await assert.rejects(verifyWebDeployment({ buildDir, fetchImpl: async () => { requests++; } }), /ENOENT/);
  assert.equal(requests, 0);
});
