import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const snapshotPath = path.join(root, 'howmuch_backend/src/main/resources/stores-snapshot.json');
const defaultOutput = path.join(root, 'docs/data/goodprice-catalog-gap-20260915.json');

const args = new Map(process.argv.slice(2).map((arg) => {
  const [key, ...rest] = arg.replace(/^--/, '').split('=');
  return [key, rest.join('=') || true];
}));
const outputPath = path.resolve(String(args.get('output') || defaultOutput));
const checkedAt = String(args.get('checked-at') || new Date().toISOString().slice(0, 10));

const REGION_CODES = [
  ['11', '서울특별시'], ['26', '부산광역시'], ['27', '대구광역시'], ['28', '인천광역시'],
  ['30', '대전광역시'], ['31', '울산광역시'], ['36', '세종특별자치시'], ['41', '경기도'],
  ['51', '강원특별자치도'], ['43', '충청북도'], ['12', '광주광역시'], ['44', '충청남도'],
  ['52', '전북특별자치도'], ['47', '경상북도'], ['48', '경상남도'], ['50', '제주특별자치도'],
];

const readJson = async (file) => JSON.parse(await readFile(file, 'utf8'));

function normalize(value) {
  let decoded = String(value ?? '');
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const next = decoded
      .replace(/&amp;/gi, '&')
      .replace(/&apos;|&#39;/gi, "'")
      .replace(/&quot;/gi, '"')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>');
    if (next === decoded) break;
    decoded = next;
  }
  return decoded.trim().replace(/\s+/g, ' ').toLowerCase();
}

const compact = (value) => normalize(value).replace(/[\s.,()\-_\/]/g, '');
const phone = (value) => String(value ?? '').replace(/\D/g, '');
const provincePrefix = /^(서울특별시|서울시|부산광역시|대구광역시|인천광역시|대전광역시|울산광역시|세종특별자치시|세종시|경기도|강원특별자치도|강원도|충청북도|충북|충청남도|충남|전라북도|전북|전북특별자치도|전라남도|전남|경상북도|경북|경상남도|경남|제주특별자치도|제주도|전남광주통합특별시)\s*/;

function addressKeys(value) {
  const raw = String(value ?? '').split(/[,(]/)[0];
  return [...new Set([compact(raw), compact(raw.replace(provincePrefix, ''))].filter(Boolean))];
}

function buildingNumbers(value) {
  return [...String(value ?? '').matchAll(/(?:^|\D)(\d{1,5})(?:-\d{1,5})?(?=\D|$)/g)].map((match) => match[1]);
}

function addressMatches(left, right) {
  const leftKeys = addressKeys(left);
  const rightKeys = addressKeys(right);
  if (leftKeys[0] && rightKeys[0]
      && (leftKeys[0] === rightKeys[0] || leftKeys[0].includes(rightKeys[0]) || rightKeys[0].includes(leftKeys[0]))) return true;
  if (leftKeys[1] && rightKeys[1] && leftKeys[1] === rightKeys[1]) return true;
  const numbers = buildingNumbers(left);
  const otherNumbers = buildingNumbers(right);
  return numbers.length > 0 && numbers.some((number) => otherNumbers.includes(number))
    && leftKeys.some((a) => rightKeys.some((b) => a.slice(-6) === b.slice(-6)));
}

function nameMatches(left, right) {
  const a = compact(left);
  const b = compact(right);
  if (!a || !b || (a.length < 2 && b.length < 2)) return false;
  return a === b || (a.length >= 3 && b.length >= 3 && (a.includes(b) || b.includes(a)));
}

function candidatePhone(candidate) {
  return phone(candidate.bsshTelno || [candidate.bsshTelnoFrst, candidate.bsshTelnoMiddle, candidate.bsshTelnoLast].join(''));
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

function haversineMeters(lat1, lng1, lat2, lng2) {
  const rad = Math.PI / 180;
  const dLat = (lat2 - lat1) * rad;
  const dLng = (lng2 - lng1) * rad;
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function validCoordinate(lat, lng) {
  return Number.isFinite(lat) && Number.isFinite(lng)
    && lat >= 33 && lat <= 39 && lng >= 124 && lng <= 132;
}

async function fetchCandidates() {
  const all = [];
  for (const [code, label] of REGION_CODES) {
    const params = new URLSearchParams({
      swLat: '33', swLng: '124', neLat: '39', neLng: '132', level: '1',
      srchCtpvCd: code, srchSggCd: '', srchIndutyCdArr: '', srchParkingYn: '', srchPackingYn: '',
      srchDlvrYn: '', srchRsvtYn: '', srchMwmnToiletSeYn: '', srchGrpUsePosblYn: '', srchWrlessYn: '',
      srchComponYn: '', srchInfntFcltyYn: '', srchPwdbsFcltyYn: '', srchPregnantPrefrYn: '',
      srchAreaCrrncyYn: '', srchBsshNm: '', srchKeyword: '',
    });
    const response = await fetch('https://www.goodprice.go.kr/bssh/selectMapData.json', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: params,
      signal: AbortSignal.timeout(60_000),
    });
    if (!response.ok) throw new Error(`Goodprice map request failed for ${code}: HTTP ${response.status}`);
    const data = await response.json();
    if (data.mode !== 'point' || !Array.isArray(data.items)) throw new Error(`Goodprice map returned ${data.mode} for ${code}`);
    all.push(...data.items.map((item) => ({ ...item, province: label })));
    console.error(`Fetched ${label}: ${data.items.length}`);
  }
  return all;
}

function buildGrid(stores, cellSize = 0.01) {
  const grid = new Map();
  const add = (lat, lng, store) => {
    const key = `${Math.floor(lat / cellSize)}:${Math.floor(lng / cellSize)}`;
    const bucket = grid.get(key) || [];
    bucket.push(store);
    grid.set(key, bucket);
  };
  for (const store of stores) {
    const lat = Number(store.latitude);
    const lng = Number(store.longitude);
    if (validCoordinate(lat, lng)) add(lat, lng, store);
  }
  return { grid, cellSize };
}

function nearestSnapshot(candidate, index) {
  const lat = Number(candidate.lat);
  const lng = Number(candidate.lot);
  if (!validCoordinate(lat, lng)) return { store: null, distanceM: null };
  const centerLat = Math.floor(lat / index.cellSize);
  const centerLng = Math.floor(lng / index.cellSize);
  let best = { store: null, distanceM: Infinity };
  // 5x5 cells cover about 2.2km in latitude, enough for an audit threshold
  // that distinguishes an address/geocode drift from an unrelated shop.
  for (let dLat = -2; dLat <= 2; dLat += 1) {
    for (let dLng = -2; dLng <= 2; dLng += 1) {
      const bucket = index.grid.get(`${centerLat + dLat}:${centerLng + dLng}`) || [];
      for (const store of bucket) {
        const distanceM = haversineMeters(lat, lng, Number(store.latitude), Number(store.longitude));
        if (distanceM < best.distanceM) best = { store, distanceM };
      }
    }
  }
  return { store: best.store, distanceM: Number.isFinite(best.distanceM) ? best.distanceM : null };
}

function exactMatches(candidate, snapshot) {
  const candidateName = candidate.bsshNm;
  const candidatePhoneValue = candidatePhone(candidate);
  const matches = [];
  for (const store of snapshot) {
    if (!nameMatches(store.storeName, candidateName) || !addressMatches(store.address, candidate.roadNmAddr)) continue;
    const storePhone = phone(store.phoneNumber);
    if (candidatePhoneValue.length >= 8 && storePhone.length >= 8 && candidatePhoneValue !== storePhone) continue;
    matches.push(store);
  }
  return matches;
}

const [snapshot, candidates] = await Promise.all([
  readJson(snapshotPath),
  fetchCandidates(),
]);
const grid = buildGrid(snapshot);
const rows = candidates.map((candidate) => {
  const exact = exactMatches(candidate, snapshot);
  const nearest = nearestSnapshot(candidate, grid);
  const photoUrls = imageUrls(candidate);
  const status = exact.length === 1
    ? 'matched-by-name-address'
    : exact.length > 1
      ? 'ambiguous-name-address'
      : nearest.distanceM !== null && nearest.distanceM <= 250
        ? 'nearby-snapshot-possible-duplicate'
        : 'official-only-candidate';
  return {
    bsshSn: String(candidate.bsshSn || ''),
    storeName: String(candidate.bsshNm || '').trim(),
    address: String(candidate.roadNmAddr || '').trim(),
    phoneNumber: candidatePhone(candidate),
    industry: String(candidate.indutyNm || '').trim(),
    province: candidate.province,
    latitude: Number(candidate.lat),
    longitude: Number(candidate.lot),
    photoCount: photoUrls.length,
    photoUrls,
    status,
    nearestDistanceM: nearest.distanceM === null ? null : Math.round(nearest.distanceM),
    nearestStoreName: nearest.store?.storeName,
    exactSnapshotStoreIds: exact.map((store) => store.storeId || null),
    sourceUrl: `https://www.goodprice.go.kr/bssh/bsshInfo.do?bsshSn=${candidate.bsshSn}`,
  };
});

const counts = rows.reduce((result, row) => {
  result[row.status] = (result[row.status] || 0) + 1;
  if (row.photoCount > 0) result.photos += 1;
  return result;
}, { photos: 0 });
const officialOnly = rows.filter((row) => row.status === 'official-only-candidate');
const officialOnlyWithPhotos = officialOnly.filter((row) => row.photoCount > 0);
const byProvince = {};
for (const row of officialOnly) byProvince[row.province] = (byProvince[row.province] || 0) + 1;

const report = {
  checkedAt,
  sources: {
    publicDataSnapshot: 'howmuch_backend/src/main/resources/stores-snapshot.json',
    goodpriceMapApi: 'https://www.goodprice.go.kr/bssh/selectMapData.json',
  },
  snapshotCount: snapshot.length,
  goodpriceMapCount: rows.length,
  goodpriceMapPhotoCount: counts.photos,
  counts,
  officialOnlyByProvince: byProvince,
  methodology: {
    exactMatch: '정규화 상호 + 도로명 주소가 일치하고, 양쪽 전화번호가 모두 있으면 전화번호도 일치해야 함',
    nearbyDuplicateThresholdMeters: 250,
    candidateDefinition: '정확 매칭이 없고 유효 좌표 기준 가장 가까운 스냅샷 매장이 250m보다 멀리 있는 행',
    caveat: '공식 원본 간 갱신 시점·주소 표기·좌표 품질이 다를 수 있어 후보는 자동 등록 전 중복 검토가 필요함',
  },
  officialOnlyCandidates: officialOnly,
  officialOnlyWithPhotos,
};
await writeFile(outputPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({
  output: path.relative(root, outputPath),
  snapshotCount: report.snapshotCount,
  goodpriceMapCount: report.goodpriceMapCount,
  goodpriceMapPhotoCount: report.goodpriceMapPhotoCount,
  counts: report.counts,
  officialOnlyWithPhotos: officialOnlyWithPhotos.length,
}, null, 2));
