import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const catalogPath = path.join(root, 'howmuch_backend/src/main/resources/store-hours.json');
const snapshotPath = path.join(root, 'howmuch_backend/src/main/resources/stores-snapshot.json');
const harvestedPath = path.join(root, 'docs/data/harvested-photos.json');

const args = new Map(process.argv.slice(2).map((arg) => {
  const [key, ...rest] = arg.replace(/^--/, '').split('=');
  return [key, rest.join('=') || true];
}));
const inputPath = String(args.get('input') || '');
const dryRun = args.has('dry-run');
const checkedAt = String(args.get('checked-at') || new Date().toISOString().slice(0, 10));
const region = String(args.get('region') || '경기권');
const regionCode = String(args.get('region-code') || '41');

const readJson = async (file) => JSON.parse(await readFile(file, 'utf8'));
const normalize = (value) => String(value ?? '').trim().replace(/\s+/g, ' ').toLowerCase();
const compact = (value) => normalize(value).replace(/[\s.,()\-_/]/g, '');
const phone = (value) => String(value ?? '').replace(/\D/g, '');
const storeId = (store) => store.storeId || `store_${createHash('sha256').update(
  [store.storeName, store.address, store.phoneNumber].map(normalize).join('|'),
).digest('hex').slice(0, 24)}`;

function addressKey(value) {
  return compact(String(value ?? '').split(/[,(]/)[0]);
}

function buildingNumbers(value) {
  return [...String(value ?? '').matchAll(/(?:^|\D)(\d{1,5})(?:-\d{1,5})?(?=\D|$)/g)].map((m) => m[1]);
}

function addressMatches(left, right) {
  const a = addressKey(left);
  const b = addressKey(right);
  if (!a || !b) return false;
  if (a === b || a.includes(b) || b.includes(a)) return true;
  const numbers = buildingNumbers(left);
  const otherNumbers = buildingNumbers(right);
  return numbers.length > 0 && numbers.some((n) => otherNumbers.includes(n))
    && (a.slice(0, 8) === b.slice(0, 8) || a.slice(-8) === b.slice(-8));
}

function nameMatches(left, right) {
  const a = compact(left);
  const b = compact(right);
  if (!a || !b || (a.length < 2 && b.length < 2)) return false;
  return a === b || (a.length >= 3 && b.length >= 3 && (a.includes(b) || b.includes(a)));
}

function candidateScore(store, candidate) {
  const name = nameMatches(store.storeName, candidate.bsshNm);
  const address = addressMatches(store.address, candidate.roadNmAddr);
  const leftPhone = phone(store.phoneNumber);
  const rightPhone = phone(candidate.bsshTelno || [candidate.bsshTelnoFrst, candidate.bsshTelnoMiddle, candidate.bsshTelnoLast].join(''));
  const samePhone = leftPhone.length >= 8 && rightPhone.length >= 8 && leftPhone === rightPhone;
  if (leftPhone.length >= 8 && rightPhone.length >= 8 && leftPhone !== rightPhone) return -1;
  if (!name || !address) return -1;
  return (name && address ? 100 : 0) + (samePhone ? 20 : 0);
}

function imageUrls(candidate) {
  const urls = [];
  for (const index of [1, 2, 3]) {
    const folder = String(candidate[`fileCours${index}`] || '').trim().replace(/^\/+|\/+$/g, '');
    const fileId = String(candidate[`thumnAtchFileOrginlNm${index}`] || '').trim();
    if (folder && fileId) {
      urls.push(`https://www.goodprice.go.kr/comm/showImageFile.do?fileCours=/bssh/${folder}/&fileId=${fileId}`);
    }
  }
  return [...new Set(urls)];
}

async function loadCandidates() {
  if (inputPath) return (await readJson(inputPath)).items || [];
  const bounds = {
    '11': [37.35, 126.75, 37.70, 127.25],
    '41': [36.80, 126.30, 38.30, 127.80],
  }[regionCode];
  if (!bounds) throw new Error(`No default bounds for region code ${regionCode}; pass --input=...`);
  const [swLat, swLng, neLat, neLng] = bounds;
  const params = new URLSearchParams({
    swLat, swLng, neLat, neLng, level: '1',
    srchCtpvCd: regionCode, srchSggCd: '', srchIndutyCdArr: '',
    srchParkingYn: '', srchPackingYn: '', srchDlvrYn: '', srchRsvtYn: '',
    srchMwmnToiletSeYn: '', srchGrpUsePosblYn: '', srchWrlessYn: '',
    srchComponYn: '', srchInfntFcltyYn: '', srchPwdbsFcltyYn: '',
    srchPregnantPrefrYn: '', srchAreaCrrncyYn: '', srchBsshNm: '', srchKeyword: '',
  });
  const response = await fetch('https://www.goodprice.go.kr/bssh/selectMapData.json', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: params,
    signal: AbortSignal.timeout(60_000),
  });
  if (!response.ok) throw new Error(`Goodprice map request failed: HTTP ${response.status}`);
  const data = await response.json();
  if (data.mode !== 'point' || !Array.isArray(data.items)) throw new Error(`Goodprice map returned ${data.mode}, expected point`);
  return data.items;
}

const [catalog, snapshot, harvested] = await Promise.all([
  readJson(catalogPath),
  readJson(snapshotPath),
  readJson(harvestedPath),
]);
const candidates = await loadCandidates();

const byName = new Map();
for (const store of snapshot) {
  const key = compact(store.storeName);
  if (!key) continue;
  const list = byName.get(key) || [];
  list.push(store);
  byName.set(key, list);
}
const catalogById = new Map(catalog.map((entry) => [entry.storeId, entry]));
const matches = [];
const rejected = [];
const seenCatalogIds = new Set();

for (const candidate of candidates) {
  const candidateName = compact(candidate.bsshNm);
  const direct = byName.get(candidateName) || [];
  const pool = direct.length ? direct : snapshot.filter((store) => nameMatches(store.storeName, candidate.bsshNm));
  const scored = pool.map((store) => ({ store, score: candidateScore(store, candidate) }))
    .filter((row) => row.score >= 0)
    .sort((a, b) => b.score - a.score);
  const best = scored[0];
  const ambiguous = best && scored[1] && best.score === scored[1].score
    && storeId(best.store) !== storeId(scored[1].store);
  const urls = imageUrls(candidate);
  if (!best || ambiguous || urls.length === 0) {
    if (urls.length > 0) rejected.push({ bsshSn: candidate.bsshSn, bsshNm: candidate.bsshNm, reason: !best ? 'no-match' : ambiguous ? 'ambiguous' : 'no-images' });
    continue;
  }
  const id = storeId(best.store);
  if (seenCatalogIds.has(id)) {
    rejected.push({ bsshSn: candidate.bsshSn, bsshNm: candidate.bsshNm, reason: 'duplicate-catalog-match', storeId: id });
    continue;
  }
  const entry = catalogById.get(id);
  if (!entry) {
    rejected.push({ bsshSn: candidate.bsshSn, bsshNm: candidate.bsshNm, reason: 'missing-hours-entry', storeId: id });
    continue;
  }
  seenCatalogIds.add(id);
  matches.push({ id, entry, candidate, urls });
}

const additions = matches.filter(({ entry }) => !(entry.imageUrls || []).length);
const enrichments = matches.filter(({ entry, urls }) => {
  const current = new Set(entry.imageUrls || []);
  return urls.some((url) => !current.has(url));
});
console.log(JSON.stringify({
  region,
  candidates: candidates.length,
  matched: matches.length,
  additions: additions.length,
  enrichments: enrichments.length,
  alreadyPhotographed: matches.length - additions.length,
  rejected: rejected.length,
  sampleAdditions: additions.slice(0, 10).map(({ entry, candidate, urls }) => ({ storeId: entry.storeId, storeName: entry.storeName, address: entry.address, bsshSn: candidate.bsshSn, photos: urls.length })),
}, null, 2));

if (dryRun) process.exit(0);

for (const { entry, candidate, urls } of matches) {
  entry.imageUrls = [...new Set([...(entry.imageUrls || []), ...urls])];
  entry.sourceUrl = `https://www.goodprice.go.kr/bssh/bsshInfo.do?bsshSn=${candidate.bsshSn}`;
  entry.sourceName = entry.sourceName || '행정안전부 착한가격업소';
  entry.checkedAt = checkedAt;
  harvested[entry.storeId] = {
    ...(harvested[entry.storeId] || {}),
    storeId: entry.storeId,
    storeName: entry.storeName,
    address: entry.address,
    phoneNumber: entry.phoneNumber,
    sourceUrl: entry.sourceUrl,
    imageUrls: entry.imageUrls,
  };
}

await writeFile(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`);
await writeFile(harvestedPath, `${JSON.stringify(harvested, null, 2)}\n`);
