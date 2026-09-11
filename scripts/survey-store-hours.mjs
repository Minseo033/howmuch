import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const origin = 'https://www.goodprice.go.kr';
export const normalize = value => String(value ?? '').trim().replace(/\s+/g, ' ').toLowerCase();
export function storeId(store) {
  return store.storeId || `store_${createHash('sha256').update(
    [store.storeName, store.address, store.phoneNumber].map(normalize).join('|'),
  ).digest('hex').slice(0, 24)}`;
}

const compact = value => normalize(value).replace(/\s/g, '');
const phone = value => String(value ?? '').replace(/\D/g, '');
// Compare the full road address up to the building number; do not match by name alone.
const road = value => compact(String(value ?? '').split(/[,(]/)[0]);
export function matches(store, candidate) {
  const sameName = compact(store.storeName) === compact(candidate.bsshNm);
  const sameRoad = road(store.address) !== '' && road(store.address) === road(candidate.roadNmAddr);
  const leftPhone = phone(store.phoneNumber), rightPhone = phone(candidate.bsshTelno);
  const phoneConflict = leftPhone.length >= 8 && rightPhone.length >= 8 && leftPhone !== rightPhone;
  return sameName && sameRoad && !phoneConflict;
}

export function cleanHours(raw) {
  // ponytail: preserve the official prose; only a reviewed structured schedule can drive open/closed status.
  return String(raw ?? '').replace(/<br\s*\/?\s*>/gi, '\n').replace(/<[^>]*>/g, '')
    .replace(/&nbsp;|&#160;/g, ' ').replace(/&amp;/g, '&')
    .replace(/\r\n?/g, '\n').replace(/[ \t]+/g, ' ').replace(/\n */g, '\n').trim();
}

export function usableHours(value) {
  return value.length <= 1000 && /(?:\d{1,2}\s*[:시]|24\s*시간)/.test(value)
    && !/정보\s*없|미등록|미정|확인\s*필요/.test(value);
}

export function selectSample(stores) {
  const districts = new Map();
  for (const store of stores) {
    if (!String(store.address).startsWith('서울특별시 ') || !/음식|한식|중식|일식|분식|양식|외식/.test(store.industry ?? '')) continue;
    const district = String(store.address).split(' ')[1];
    if (!districts.has(district)) districts.set(district, []);
    districts.get(district).push(store);
  }
  const sample = [];
  for (const [, rows] of [...districts].sort(([a], [b]) => a.localeCompare(b, 'ko'))) {
    // Fixed hash ordering avoids selecting only alphabetically early store names.
    sample.push(...rows.sort((a, b) => storeId(a).localeCompare(storeId(b))).slice(0, 4));
  }
  if (sample.length !== 100) throw new Error(`Expected 4 food stores in each of 25 districts; got ${sample.length}`);
  return sample;
}

async function request(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: { 'User-Agent': 'HowMuch-hours-pilot/1.0 (100-store public-data verification)', ...options.headers },
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return response;
}

async function survey(store) {
  const start = Date.now();
  const base = { storeId: storeId(store), storeName: store.storeName, address: store.address, phoneNumber: store.phoneNumber ?? '' };
  try {
    const query = new URLSearchParams({ srchBsshNm: store.storeName, srchCtpvCd: '11' });
    const html = await (await request(`${origin}/bssh/bsshList.do?${query}`)).text();
    const ids = [...new Set([...html.matchAll(/goInfo\('(\d+)'\)/g)].map(match => match[1]))];
    if (ids.length > 5) return { ...base, status: 'REVIEW_REQUIRED', reason: 'too_many_candidates', candidateIds: ids };
    const candidates = [];
    for (const id of ids) {
      await delay(300);
      const body = new URLSearchParams({ bsshSn: id });
      const data = await (await request(`${origin}/bssh/bsshInfo.json`, { method: 'POST', body })).json();
      const item = data.result;
      if (!item || typeof item !== 'object') throw new Error('Unexpected detail response');
      candidates.push({ bsshSn: String(item.bsshSn), bsshNm: item.bsshNm,
        roadNmAddr: item.roadNmAddr, roadNmDtlAddr: item.roadNmDtlAddr,
        bsshTelno: item.bsshTelno, bsnHr: item.bsnHr ?? '' });
    }
    const matched = candidates.filter(candidate => matches(store, candidate));
    if (matched.length !== 1) return { ...base, status: 'REVIEW_REQUIRED', reason: matched.length > 1 ? 'ambiguous_match' : 'no_exact_match', candidates };
    const source = matched[0];
    const text = cleanHours(source.bsnHr);
    return { ...base, status: usableHours(text) ? 'SOURCE_MATCHED' : 'HOURS_UNAVAILABLE',
      text, sourceName: '행정안전부 착한가격업소',
      sourceUrl: `${origin}/bssh/bsshInfo.do?bsshSn=${source.bsshSn}`,
      checkedAt: new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Seoul' }).format(new Date()),
      evidence: source, elapsedMs: Date.now() - start };
  } catch (error) {
    return { ...base, status: 'FETCH_FAILED', reason: error.message, elapsedMs: Date.now() - start };
  }
}

async function main() {
  const output = process.argv[2];
  if (!output) throw new Error('Usage: node scripts/survey-store-hours.mjs <new-output-directory>');
  await mkdir(output, { recursive: true });
  const stores = JSON.parse(await readFile(path.join(root, 'howmuch_backend/src/main/resources/stores-snapshot.json'), 'utf8'));
  const sample = selectSample(stores);
  const results = [];
  // Sequential requests, bounded to 100 stores; restart resumes completed rows.
  for (const store of sample) {
    const filename = path.join(output, `${storeId(store)}.json`);
    let result;
    try { result = JSON.parse(await readFile(filename, 'utf8')); }
    catch (error) {
      if (error.code !== 'ENOENT') throw error;
      result = await survey(store);
      await writeFile(filename, JSON.stringify(result, null, 2) + '\n', { flag: 'wx' });
      await delay(400);
    }
    results.push(result);
    console.log(`${results.length}/100 ${result.status} ${store.storeName}`);
  }
  const counts = Object.fromEntries([...new Set(results.map(row => row.status))].map(status => [status, results.filter(row => row.status === status).length]));
  await writeFile(path.join(output, 'survey.json'), JSON.stringify({ scope: '서울특별시 25개 구별 음식점 4곳, 고정 표본', counts, results }, null, 2) + '\n');
  console.log(JSON.stringify(counts));
  console.log('Candidate data only. Review source evidence before adding records to store-hours.json.');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
