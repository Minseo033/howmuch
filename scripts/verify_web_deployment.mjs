import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const releaseFiles = [
  'index.html', 'main.dart.js', 'flutter_bootstrap.js', 'flutter.js',
  'flutter_service_worker.js', 'admin.html', 'version.json', 'manifest.json',
];
const routes = ['/', '/home', '/login'];
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

// Compare the actual public alias, not just the protected deployment URL or HTTP status.
export async function verifyWebDeployment({
  baseUrl = 'https://howmuch-zeta.vercel.app',
  buildDir = new URL('../build/web/', import.meta.url),
  fetchImpl = fetch,
  timeoutMs = 25000,
} = {}) {
  const base = new URL(baseUrl);
  if (!['http:', 'https:'].includes(base.protocol) || base.username || base.password) {
    throw new Error('검증 주소는 인증 정보가 없는 HTTP(S) URL이어야 합니다.');
  }
  const directory = buildDir instanceof URL ? buildDir : pathToFileURL(`${resolve(buildDir)}/`);
  // Fail before network access if the local release is incomplete.
  const expected = new Map(await Promise.all(releaseFiles.map(async (file) => [
    file, sha256(await readFile(new URL(file, directory))),
  ])));
  const results = [];
  for (const path of [...releaseFiles, ...routes]) {
    try {
      const response = await fetchImpl(new URL(path, base), {
        redirect: 'manual',
        headers: { 'Cache-Control': 'no-cache' },
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (response.status !== 200) {
        await response.body?.cancel();
        throw new Error(`HTTP ${response.status} (공개 주소에서 직접 200 응답 필요)`);
      }
      const actual = sha256(Buffer.from(await response.arrayBuffer()));
      const reference = expected.get(path.startsWith('/') ? 'index.html' : path);
      if (actual !== reference) throw new Error('로컬 release와 SHA-256 불일치');
      results.push({ path, ok: true });
    } catch (error) {
      // Do not print response bodies, redirect URLs, or authentication information.
      results.push({ path, ok: false, error: error.name === 'TimeoutError'
        ? '응답 시간 초과' : error.message });
    }
  }
  return results;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const results = await verifyWebDeployment({
      baseUrl: process.argv[2], buildDir: process.argv[3],
    });
    for (const result of results) {
      console.log(`${result.ok ? 'PASS' : 'FAIL'} ${result.path}${result.error ? `: ${result.error}` : ''}`);
    }
    process.exitCode = results.every((result) => result.ok) ? 0 : 1;
  } catch (error) {
    console.error(`배포 검증 실패: ${error.message}`);
    process.exitCode = 1;
  }
}
