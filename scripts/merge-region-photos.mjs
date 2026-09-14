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
const allRegions = args.has('all-regions');
const deepScan = args.has('deep-scan');
const includeNewRecords = args.has('include-new-records');

const REGION_CODES = [
  ['11', '서울'], ['26', '부산'], ['27', '대구'], ['28', '인천'],
  ['30', '대전'], ['31', '울산'], ['36', '세종'], ['41', '경기'],
  ['51', '강원'], ['43', '충북'], ['12', '광주'], ['44', '충남'],
  ['52', '전북'], ['47', '경북'], ['48', '경남'], ['50', '제주'],
];

const readJson = async (file) => JSON.parse(await readFile(file, 'utf8'));
const normalize = (value) => String(value ?? '')
  .replace(/&amp;apos;|&apos;|&#39;|&amp;/gi, "'")
  .trim().replace(/\s+/g, ' ').toLowerCase();
const compact = (value) => normalize(value).replace(/[\s.,()\-_/]/g, '');
const phone = (value) => String(value ?? '').replace(/\D/g, '');
const storeId = (store) => store.storeId || `store_${createHash('sha256').update(
  [store.storeName, store.address, store.phoneNumber].map(normalize).join('|'),
).digest('hex').slice(0, 24)}`;

const provincePrefix = /^(서울특별시|서울시|부산광역시|대구광역시|인천광역시|대전광역시|울산광역시|세종특별자치시|세종시|경기도|강원특별자치도|강원도|충청북도|충북|충청남도|충남|전라북도|전북|전북특별자치도|전라남도|전남|경상북도|경북|경상남도|경남|제주특별자치도|제주도|전남광주통합특별시)\s*/;

function addressKeys(value) {
  const raw = String(value ?? '').split(/[,(]/)[0];
  return [...new Set([compact(raw), compact(raw.replace(provincePrefix, ''))].filter(Boolean))];
}

function buildingNumbers(value) {
  return [...String(value ?? '').matchAll(/(?:^|\D)(\d{1,5})(?:-\d{1,5})?(?=\D|$)/g)].map((m) => m[1]);
}

function addressMatches(left, right) {
  const leftKeys = addressKeys(left);
  const rightKeys = addressKeys(right);
  if (leftKeys[0] && rightKeys[0]
      && (leftKeys[0] === rightKeys[0] || leftKeys[0].includes(rightKeys[0]) || rightKeys[0].includes(leftKeys[0]))) return true;
  if (leftKeys[1] && rightKeys[1] && leftKeys[1] === rightKeys[1]) return true;
  const numbers = buildingNumbers(left);
  const otherNumbers = buildingNumbers(right);
  return numbers.length > 0 && numbers.some((n) => otherNumbers.includes(n))
    && leftKeys.some((a) => rightKeys.some((b) => a.slice(-6) === b.slice(-6)));
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

function fileListImageUrls(fileList) {
  if (!Array.isArray(fileList)) return [];
  const urls = [];
  for (const file of fileList) {
    const folder = String(file.fileCours || '').trim().replace(/^\/+|\/+$/g, '');
    const fileId = String(file.thumnAtchFileOrginlNm || file.atchFileOrginlNm || '').trim();
    if (folder && fileId) {
      urls.push(`https://www.goodprice.go.kr/comm/showImageFile.do?fileCours=/bssh/${folder}/&fileId=${fileId}`);
    }
  }
  return [...new Set(urls)];
}

async function detailImageUrls(candidate) {
  const params = new URLSearchParams({ bsshSn: String(candidate.bsshSn || '') });
  const response = await fetch('https://www.goodprice.go.kr/bssh/bsshInfo.json', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: params,
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) return [];
  const data = await response.json();
  return fileListImageUrls(data.fileList);
}

async function loadCandidates() {
  if (inputPath) return (await readJson(inputPath)).items || [];
  const codes = allRegions ? REGION_CODES : [[regionCode, region]];
  const candidates = [];
  for (const [code] of codes) {
    const params = new URLSearchParams({
      swLat: '33', swLng: '124', neLat: '39', neLng: '132', level: '1',
      srchCtpvCd: code, srchSggCd: '', srchIndutyCdArr: '',
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
    if (!response.ok) throw new Error(`Goodprice map request failed for ${code}: HTTP ${response.status}`);
    const data = await response.json();
    if (data.mode !== 'point' || !Array.isArray(data.items)) throw new Error(`Goodprice map returned ${data.mode} for ${code}, expected point`);
    candidates.push(...data.items);
    console.error(`Fetched ${code}: ${data.items.length} official stores`);
  }
  return candidates;
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
let matchedWithoutMapPhotos = 0;
let deepScanned = 0;
let deepScanFailures = 0;
let deepScanFound = 0;
let newRecords = 0;

for (const candidate of candidates) {
  const candidateName = compact(candidate.bsshNm);
  const direct = byName.get(candidateName) || [];
  let pool = direct.length ? direct : snapshot.filter((store) => nameMatches(store.storeName, candidate.bsshNm));
  let scored = pool.map((store) => ({ store, score: candidateScore(store, candidate) }))
    .filter((row) => row.score >= 0)
    .sort((a, b) => b.score - a.score);
  // An exact catalog name can belong to a different branch. If none of those
  // records also matches the official address, retry the broader contained-name
  // pool so names such as "행복한밥상" can match "고추장불고기(행복한밥상)".
  if (direct.length > 0 && scored.length === 0) {
    pool = snapshot.filter((store) => nameMatches(store.storeName, candidate.bsshNm));
    scored = pool.map((store) => ({ store, score: candidateScore(store, candidate) }))
      .filter((row) => row.score >= 0)
      .sort((a, b) => b.score - a.score);
  }
  const best = scored[0];
  const ambiguous = best && scored[1] && best.score === scored[1].score
    && storeId(best.store) !== storeId(scored[1].store);
  let urls = imageUrls(candidate);
  if (best && urls.length === 0) matchedWithoutMapPhotos += 1;
  if (best && !ambiguous && urls.length === 0 && deepScan) {
    deepScanned += 1;
    try {
      urls = await detailImageUrls(candidate);
      if (urls.length > 0) deepScanFound += 1;
    } catch {
      deepScanFailures += 1;
    }
  }
  if (!best || ambiguous || urls.length === 0) {
    if (urls.length > 0) rejected.push({ bsshSn: candidate.bsshSn, bsshNm: candidate.bsshNm, reason: !best ? 'no-match' : ambiguous ? 'ambiguous' : 'no-images' });
    continue;
  }
  const id = storeId(best.store);
  if (seenCatalogIds.has(id)) {
    rejected.push({ bsshSn: candidate.bsshSn, bsshNm: candidate.bsshNm, reason: 'duplicate-catalog-match', storeId: id });
    continue;
  }
  let entry = catalogById.get(id);
  if (!entry) {
    if (!includeNewRecords) {
      rejected.push({ bsshSn: candidate.bsshSn, bsshNm: candidate.bsshNm, reason: 'missing-hours-entry', storeId: id });
      continue;
    }
    entry = {
      storeId: id,
      storeName: best.store.storeName,
      address: best.store.address,
      phoneNumber: best.store.phoneNumber || '',
      status: 'SOURCE_VERIFIED',
      text: '등록된 영업시간이 없어요.',
      sourceName: '행정안전부 착한가격업소',
      sourceUrl: `https://www.goodprice.go.kr/bssh/bsshInfo.do?bsshSn=${candidate.bsshSn}`,
      checkedAt,
      parkingYn: null,
      packingYn: null,
      areaCurrency: null,
      imageUrls: [],
    };
    catalog.push(entry);
    catalogById.set(id, entry);
    newRecords += 1;
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
  matchedWithoutMapPhotos,
  deepScanned,
  deepScanFailures,
  deepScanFound,
  newRecords,
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
