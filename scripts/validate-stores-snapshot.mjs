import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { hasValidKoreanCoordinates } from './data_integrity.mjs';

export const MIN_STORES = 10_000;
/** 이름·주소가 없거나 좌표가 국외인 행. 그대로 서비스에 실리면 안 되는 데이터라 거의 없어야 한다. */
export const MAX_INVALID_RATIO = 0.005;
/** 좌표가 없는 매장은 지도에는 안 보여도 검색 목록에는 나온다. 지오코딩이 크게 망가진 경우만 막는다. */
export const MAX_MISSING_COORDINATE_RATIO = 0.05;
/** 저장소의 이전 스냅샷보다 이만큼 넘게 줄면 원천 데이터나 서버 응답 이상으로 보고 멈춘다. */
export const MAX_SHRINK_RATIO = 0.05;

const hasText = (value) => typeof value === 'string' && value.trim().length > 0;
const isAbsent = (value) => value === null || value === undefined || value === '';
// 비어 있으면 0(좌표 없음)으로 보고, 숫자·숫자 문자열만 좌표로 인정한다. 불리언 같은 값은 형식 오류다.
function coordinate(value) {
  if (isAbsent(value)) return 0;
  if (typeof value === 'number') return value;
  if (typeof value === 'string' && Number.isFinite(Number(value))) return Number(value);
  return Number.NaN;
}

export function classifySnapshotRow(store) {
  if (!store || typeof store !== 'object' || Array.isArray(store)) return 'invalid';
  if (!hasText(store.storeName) || !hasText(store.address)) return 'invalid';
  const latitude = coordinate(store.latitude);
  const longitude = coordinate(store.longitude);
  if (Number.isNaN(latitude) || Number.isNaN(longitude)) return 'invalid';
  if (latitude === 0 && longitude === 0) return 'missing-coordinates';
  return hasValidKoreanCoordinates(latitude, longitude) ? 'valid' : 'invalid';
}

export function checkSnapshot(stores, { previousCount = null, allowShrink = false } = {}) {
  const total = Array.isArray(stores) ? stores.length : 0;
  if (!Array.isArray(stores) || total < MIN_STORES) {
    throw new Error(`Snapshot must contain at least ${MIN_STORES} stores (received ${total}).`);
  }
  const counts = { valid: 0, 'missing-coordinates': 0, invalid: 0 };
  for (const store of stores) counts[classifySnapshotRow(store)] += 1;
  if (counts.invalid / total > MAX_INVALID_RATIO) {
    throw new Error(`Snapshot validation failed: ${counts.invalid}/${total} rows lack a name or address or have malformed or out-of-Korea coordinates.`);
  }
  if (counts['missing-coordinates'] / total > MAX_MISSING_COORDINATE_RATIO) {
    throw new Error(`Snapshot validation failed: ${counts['missing-coordinates']}/${total} rows have no coordinates.`);
  }
  if (!allowShrink && Number.isInteger(previousCount) && previousCount > 0
      && total < previousCount * (1 - MAX_SHRINK_RATIO)) {
    throw new Error(`Snapshot shrank from ${previousCount} to ${total} stores (more than ${MAX_SHRINK_RATIO * 100}%). `
      + 'Re-run with --allow-shrink only after confirming the removal is intended.');
  }
  return { total, valid: counts.valid, missingCoordinates: counts['missing-coordinates'], invalid: counts.invalid };
}

function previousSnapshotCount(path) {
  if (!existsSync(path)) return null;
  try {
    const previous = JSON.parse(readFileSync(path, 'utf8'));
    return Array.isArray(previous) ? previous.length : null;
  } catch {
    return null;
  }
}

function main(argv) {
  const [inputPath, outputPath, ...flags] = argv;
  if (!inputPath || !outputPath) {
    throw new Error('Usage: node scripts/validate-stores-snapshot.mjs <input> <output> [--allow-shrink]');
  }
  const stores = JSON.parse(readFileSync(inputPath, 'utf8'));
  // The output path holds the committed snapshot, which is the baseline for the shrink check.
  const summary = checkSnapshot(stores, {
    previousCount: previousSnapshotCount(outputPath),
    allowShrink: flags.includes('--allow-shrink'),
  });
  writeFileSync(outputPath, JSON.stringify(stores));
  console.log(`Validated ${summary.total} stores (${summary.missingCoordinates} without coordinates, `
    + `${summary.invalid} invalid) and wrote ${outputPath}.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main(process.argv.slice(2));
}
