import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const snapshotPath = path.join(root, 'howmuch_backend/src/main/resources/stores-snapshot.json');
const supplementPath = path.join(root, 'howmuch_backend/src/main/resources/stores-supplement.json');
const catalogPath = path.join(root, 'howmuch_backend/src/main/resources/store-hours.json');
const harvestedPath = path.join(root, 'docs/data/harvested-photos.json');
const gapPath = path.join(root, 'docs/data/goodprice-catalog-gap-20260915.json');
const auditPath = path.join(root, 'docs/data/goodprice-supplement-audit-20260915.json');

const args = new Map(process.argv.slice(2).map((arg) => {
  const [key, ...rest] = arg.replace(/^--/, '').split('=');
  return [key, rest.join('=') || true];
}));
const apply = args.has('apply');
const checkedAt = String(args.get('checked-at') || new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Seoul',
}).format(new Date()));

const readJson = async (file, fallback = null) => {
  try { return JSON.parse(await readFile(file, 'utf8')); }
  catch (error) {
    if (error.code === 'ENOENT' && fallback !== null) return fallback;
    throw error;
  }
};

function decodeEntities(value) {
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
  return decoded;
}

const normalize = (value) => decodeEntities(value).trim().replace(/\s+/g, ' ').toLowerCase();
const compact = (value) => normalize(value).replace(/[\s.,()\-_\/]/g, '');
const phone = (value) => String(value ?? '').replace(/\D/g, '');
const road = (value) => compact(String(value ?? '').split(/[,(]/)[0]);
const validPhone = (value) => phone(value).length >= 8;

function stableStoreId(store) {
  const canonical = [store.storeName, store.address, store.phoneNumber].map(normalize).join('|');
  return `store_${createHash('sha256').update(canonical).digest('hex').slice(0, 24)}`;
}

function cleanText(value) {
  return decodeEntities(value)
    .replace(/<br\s*\/?\s*>/gi, '\n')
    .replace(/<[^>]*>/g, '')
    .replace(/&nbsp;|&#160;/gi, ' ')
    .replace(/\r\n?/g, '\n')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n */g, '\n')
    .trim();
}

function usableHours(value) {
  return value.length > 0 && value.length <= 1000
    && /(?:\d{1,2}\s*[:시]|24\s*시간)/.test(value)
    && !/^[-–—]$/.test(value)
    && !/정보\s*없|미등록|미정|확인\s*필요/.test(value);
}

function flag(value) {
  if (value === 'Y') return true;
  if (value === 'N') return false;
  return null;
}

function areaCurrency(result) {
  const types = [];
  if (result.areaCrrncyPaperYn === 'Y') types.push('지류형');
  if (result.areaCrrncyMobileYn === 'Y') types.push('모바일형');
  if (result.areaCrrncyCardYn === 'Y') types.push('카드형');
  if (types.length > 0) return `지역화폐(${types.join(', ')})`;
  const value = cleanText(result.areaCrrncy || '');
  return value || null;
}

function imageUrls(fileList) {
  if (!Array.isArray(fileList)) return [];
  return [...new Set(fileList.flatMap((file) => {
    const folder = String(file.fileCours || '').trim().replace(/^\/+|\/+$/g, '');
    const fileId = String(file.thumnAtchFileOrginlNm || file.atchFileOrginlNm || '').trim();
    return folder && fileId
      ? [`https://www.goodprice.go.kr/comm/showImageFile.do?fileCours=/bssh/${folder}/&fileId=${fileId}`]
      : [];
  }))];
}

function validCoordinate(lat, lng) {
  return Number.isFinite(lat) && Number.isFinite(lng)
    && lat >= 33 && lat <= 39 && lng >= 124 && lng <= 132;
}

function haversineMeters(lat1, lng1, lat2, lng2) {
  const rad = Math.PI / 180;
  const dLat = (lat2 - lat1) * rad;
  const dLng = (lng2 - lng1) * rad;
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function nameMatches(left, right) {
  const a = compact(left);
  const b = compact(right);
  if (!a || !b || (a.length < 3 && b.length < 3)) return false;
  return a === b || (a.length >= 3 && b.length >= 3 && (a.includes(b) || b.includes(a)));
}

async function fetchDetail(bsshSn) {
  let lastError;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const response = await fetch('https://www.goodprice.go.kr/bssh/bsshInfo.json', {
        method: 'POST',
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          'user-agent': 'HowMuch-public-data-verifier/1.0',
        },
        body: new URLSearchParams({ bsshSn: String(bsshSn) }),
        signal: AbortSignal.timeout(30_000),
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      if (!data.result || typeof data.result !== 'object') throw new Error('missing result');
      return data;
    } catch (error) {
      lastError = error;
      if (attempt < 3) await new Promise((resolve) => setTimeout(resolve, attempt * 250));
    }
  }
  throw lastError;
}

async function mapLimit(items, limit, worker) {
  const results = new Array(items.length);
  let next = 0;
  async function run() {
    while (true) {
      const index = next;
      next += 1;
      if (index >= items.length) return;
      results[index] = await worker(items[index], index);
    }
  }
  await Promise.all(Array.from({ length: limit }, () => run()));
  return results;
}

function selectedMenus(menuList) {
  if (!Array.isArray(menuList)) return [];
  return menuList
    .filter((menu) => cleanText(menu.menuNm).length > 0
      && Number.isFinite(Number(menu.menuPc)) && Number(menu.menuPc) >= 0)
    .sort((a, b) => (b.menuDsgnYn === 'Y') - (a.menuDsgnYn === 'Y'))
    .slice(0, 4)
    .map((menu) => ({ name: cleanText(menu.menuNm), price: String(menu.menuPc) }));
}

function snapshotDuplicateReasons(candidate, snapshot) {
  const reasons = new Set();
  const candidatePhone = phone(candidate.phoneNumber);
  for (const store of snapshot) {
    const distance = validCoordinate(Number(store.latitude), Number(store.longitude))
      ? haversineMeters(candidate.latitude, candidate.longitude, Number(store.latitude), Number(store.longitude))
      : Infinity;
    const samePhone = candidatePhone.length >= 8 && phone(store.phoneNumber) === candidatePhone;
    const sameName = nameMatches(store.storeName, candidate.storeName);
    const sameRoad = road(store.address) && road(store.address) === road(candidate.address);
    const sameDistrict = normalize(store.cityDistrict) === normalize(candidate.cityDistrict);
    const sameIndustry = normalize(store.industry) === normalize(candidate.industry);
    if (samePhone) reasons.add('snapshot-phone-collision');
    if (sameName && sameRoad) reasons.add('snapshot-name-address-collision');
    if (distance <= 250) reasons.add('snapshot-within-250m');
    if (sameName && sameDistrict && distance <= 2000) reasons.add('snapshot-nearby-same-name');
    if (sameRoad && sameIndustry) reasons.add('snapshot-address-industry-collision');
  }
  return [...reasons];
}

const [snapshot, gap, catalog, harvested, previousSupplement] = await Promise.all([
  readJson(snapshotPath), readJson(gapPath), readJson(catalogPath), readJson(harvestedPath, {}), readJson(supplementPath, []),
]);
const sourceCandidates = gap.officialOnlyCandidates || [];
const previousSupplementIds = new Set(previousSupplement.map((store) => store.storeId));
const preservedCatalog = catalog.filter((entry) => !previousSupplementIds.has(entry.storeId));
const catalogSourceIds = new Set(preservedCatalog.map((entry) => String(entry.sourceUrl || '').match(/bsshSn=(\d+)/)?.[1]).filter(Boolean));
const catalogIds = new Set(preservedCatalog.map((entry) => entry.storeId));
const existingImageUrls = new Set(preservedCatalog.flatMap((entry) => entry.imageUrls || []));

const fetched = await mapLimit(sourceCandidates, 6, async (candidate, index) => {
  try {
    const detail = await fetchDetail(candidate.bsshSn);
    if ((index + 1) % 50 === 0 || index + 1 === sourceCandidates.length) {
      console.error(`Verified ${index + 1}/${sourceCandidates.length}`);
    }
    return { candidate, detail };
  } catch (error) {
    return { candidate, error: error.message };
  }
});

const provisional = [];
const rejected = [];
for (const row of fetched) {
  if (row.error) {
    rejected.push({ bsshSn: row.candidate.bsshSn, storeName: row.candidate.storeName, reasons: [`detail-fetch-failed:${row.error}`] });
    continue;
  }
  const { candidate, detail } = row;
  const result = detail.result;
  const reasons = [];
  if (String(result.bsshSn) !== String(candidate.bsshSn)) reasons.push('detail-id-mismatch');
  if (compact(result.bsshNm) !== compact(candidate.storeName)) reasons.push('detail-name-mismatch');
  if (road(result.roadNmAddr) !== road(candidate.address)) reasons.push('detail-address-mismatch');
  if (detail.bsshVO?.dsgnYn !== 'Y') reasons.push('not-currently-designated');
  const latitude = Number(candidate.latitude);
  const longitude = Number(candidate.longitude);
  if (!validCoordinate(latitude, longitude)) reasons.push('invalid-coordinate');
  const menus = selectedMenus(detail.menuList);
  if (menus.length === 0) reasons.push('no-confirmed-menu-price');
  if (!cleanText(result.ctpvNm) || !cleanText(result.sggNm)) reasons.push('missing-region');
  const store = {
    cityProvince: cleanText(result.ctpvNm),
    cityDistrict: cleanText(result.sggNm),
    industry: cleanText(result.indutyNm),
    storeName: cleanText(result.bsshNm),
    phoneNumber: cleanText(result.bsshTelno) || null,
    address: cleanText(result.roadNmAddr),
    latitude,
    longitude,
  };
  menus.forEach((menu, index) => {
    store[`menu${index + 1}`] = menu.name;
    store[`price${index + 1}`] = menu.price;
  });
  for (let index = menus.length; index < 4; index += 1) {
    store[`menu${index + 1}`] = null;
    store[`price${index + 1}`] = null;
  }
  store.storeId = stableStoreId(store);
  const photos = imageUrls(detail.fileList);
  if (!/^\d+$/.test(String(candidate.bsshSn))) reasons.push('invalid-source-id');
  if (!validPhone(store.phoneNumber)) reasons.push('missing-verifiable-phone');
  if (photos.length === 0) reasons.push('missing-official-photo');
  if (catalogSourceIds.has(String(candidate.bsshSn))) reasons.push('source-id-already-in-catalog');
  if (catalogIds.has(store.storeId)) reasons.push('stable-id-already-in-catalog');
  if (photos.some((url) => existingImageUrls.has(url))) reasons.push('photo-already-in-catalog');
  reasons.push(...snapshotDuplicateReasons(store, snapshot));
  if (Number(candidate.nearestDistanceM) <= 500) reasons.push('snapshot-distance-under-500m');
  if (reasons.length > 0) {
    rejected.push({ bsshSn: String(candidate.bsshSn), storeName: store.storeName, address: store.address, reasons: [...new Set(reasons)] });
    continue;
  }
  const cleanedHours = cleanText(result.bsnHr);
  provisional.push({
    bsshSn: String(candidate.bsshSn),
    store,
    details: {
      status: 'SOURCE_VERIFIED',
      text: usableHours(cleanedHours) ? cleanedHours : '등록된 영업시간이 없어요.',
      sourceName: '행정안전부 착한가격업소',
      sourceUrl: `https://www.goodprice.go.kr/bssh/bsshInfo.do?bsshSn=${candidate.bsshSn}`,
      checkedAt,
      parkingYn: flag(result.parkingYn),
      packingYn: flag(result.packingYn),
      areaCurrency: areaCurrency(result),
      imageUrls: photos,
    },
  });
}

const duplicateIndexes = new Set();
for (let left = 0; left < provisional.length; left += 1) {
  for (let right = left + 1; right < provisional.length; right += 1) {
    const a = provisional[left].store;
    const b = provisional[right].store;
    const samePhone = validPhone(a.phoneNumber) && phone(a.phoneNumber) === phone(b.phoneNumber);
    const sameNameAddress = compact(a.storeName) === compact(b.storeName) && road(a.address) === road(b.address);
    const sameAddressIndustry = road(a.address) === road(b.address) && normalize(a.industry) === normalize(b.industry);
    const distance = haversineMeters(a.latitude, a.longitude, b.latitude, b.longitude);
    const nearbySameName = distance <= 50 && nameMatches(a.storeName, b.storeName);
    const sharedPhoto = provisional[left].details.imageUrls.some((url) => provisional[right].details.imageUrls.includes(url));
    if (samePhone || sameNameAddress || sameAddressIndustry || nearbySameName || sharedPhoto) {
      duplicateIndexes.add(left);
      duplicateIndexes.add(right);
    }
  }
}

const accepted = provisional.filter((row, index) => {
  if (!duplicateIndexes.has(index)) return true;
  rejected.push({ bsshSn: row.bsshSn, storeName: row.store.storeName, address: row.store.address, reasons: ['supplement-candidate-collision'] });
  return false;
});
const supplement = accepted.map((row) => row.store);
const acceptedIds = new Set(supplement.map((store) => store.storeId));
const newCatalogEntries = accepted.map((row) => ({
  storeId: row.store.storeId,
  storeName: row.store.storeName,
  address: row.store.address,
  phoneNumber: row.store.phoneNumber || '',
  ...row.details,
}));
const nextCatalog = [...preservedCatalog, ...newCatalogEntries];
const nextHarvested = { ...harvested };
for (const previous of previousSupplement) delete nextHarvested[previous.storeId];
for (const row of accepted) {
  nextHarvested[row.store.storeId] = {
    storeId: row.store.storeId,
    storeName: row.store.storeName,
    address: row.store.address,
    phoneNumber: row.store.phoneNumber,
    sourceUrl: row.details.sourceUrl,
    imageUrls: row.details.imageUrls,
  };
}

const reasonCounts = {};
for (const row of rejected) for (const reason of row.reasons) reasonCounts[reason] = (reasonCounts[reason] || 0) + 1;
const audit = {
  checkedAt,
  sourceCandidateCount: sourceCandidates.length,
  previousSupplementCount: previousSupplement.length,
  acceptedCount: accepted.length,
  rejectedCount: rejected.length,
  acceptedWithHours: accepted.filter((row) => row.details.text !== '등록된 영업시간이 없어요.').length,
  acceptedWithPhotos: accepted.filter((row) => row.details.imageUrls.length > 0).length,
  reasonCounts,
  policy: {
    source: '행정안전부 착한가격업소 지도 후보를 개별 bsshInfo.json으로 재확인',
    required: ['현재 지정 Y', '상호·도로명 주소 원본 일치', '유효 좌표', '공식 메뉴·가격 1개 이상', '시도·시군구', '검증 가능한 전화번호', '공식 사진 1개 이상'],
    duplicateGuards: ['기존 전화·상호주소·주소업종 충돌 제외', '기존 매장 500m 이내 제외', '동일 bsshSn/storeId/사진 제외', '후보끼리 전화·상호주소·주소업종·50m 유사상호·사진 충돌 제외'],
  },
  accepted: accepted.map((row) => ({
    bsshSn: row.bsshSn,
    storeId: row.store.storeId,
    storeName: row.store.storeName,
    address: row.store.address,
    phoneNumber: row.store.phoneNumber,
    industry: row.store.industry,
    sourceUrl: row.details.sourceUrl,
  })),
  rejected,
};

await writeFile(auditPath, `${JSON.stringify(audit, null, 2)}\n`);
console.log(JSON.stringify({
  apply,
  sourceCandidates: sourceCandidates.length,
  accepted: accepted.length,
  rejected: rejected.length,
  acceptedWithHours: audit.acceptedWithHours,
  acceptedWithPhotos: audit.acceptedWithPhotos,
  totalStoresAfterApply: new Set([...snapshot, ...supplement].map(stableStoreId)).size,
  catalogAfterApply: nextCatalog.length,
  reasonCounts,
}, null, 2));

if (apply) {
  await Promise.all([
    writeFile(supplementPath, `${JSON.stringify(supplement, null, 2)}\n`),
    writeFile(catalogPath, `${JSON.stringify(nextCatalog, null, 2)}\n`),
    writeFile(harvestedPath, `${JSON.stringify(nextHarvested, null, 2)}\n`),
  ]);
  if (acceptedIds.size !== supplement.length) throw new Error('Supplement store IDs must be unique');
}
