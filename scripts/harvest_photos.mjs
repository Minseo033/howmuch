import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
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
const road = value => compact(String(value ?? '').split(/[,(]/)[0]);

export function matches(store, candidate) {
  const candName = compact(candidate.bsshNm || candidate.name || '');
  const candRoad = road(candidate.roadNmAddr || candidate.addr || '');
  const storeName = compact(store.storeName);
  const storeRoad = road(store.address || '');

  const sameName = candName === storeName || candName.includes(storeName) || storeName.includes(candName);
  if (!sameName) return false;

  const sameRoad = storeRoad !== '' && candRoad !== '' && (storeRoad.includes(candRoad) || candRoad.includes(storeRoad));
  if (!sameRoad) return false;

  const leftPhone = phone(store.phoneNumber);
  const rightPhone = phone(candidate.bsshTelno || candidate.phone || '');
  const phoneConflict = leftPhone.length >= 8 && rightPhone.length >= 8 && leftPhone !== rightPhone;
  return !phoneConflict;
}

export function getRegionCode(address) {
  const addr = String(address || '');
  if (addr.includes('서울')) return '11';
  if (addr.includes('부산')) return '26';
  if (addr.includes('대구')) return '27';
  if (addr.includes('인천')) return '28';
  if (addr.includes('광주')) return '29';
  if (addr.includes('대전')) return '30';
  if (addr.includes('울산')) return '31';
  if (addr.includes('세종')) return '36';
  if (addr.includes('경기')) return '41';
  if (addr.includes('강원')) return '51';
  if (addr.includes('충청북도') || addr.includes('충북')) return '43';
  if (addr.includes('충청남도') || addr.includes('충남')) return '44';
  if (addr.includes('전라북도') || addr.includes('전북')) return '52';
  if (addr.includes('전라남도') || addr.includes('전남')) return '46';
  if (addr.includes('경상북도') || addr.includes('경북')) return '47';
  if (addr.includes('경상남도') || addr.includes('경남')) return '48';
  if (addr.includes('제주')) return '50';
  return null;
}

export function extractImageUrls(fileList) {
  if (!Array.isArray(fileList) || fileList.length === 0) return [];
  const urls = [];
  for (const file of fileList) {
    const cours = String(file.fileCours || '').trim().replace(/^\/+|\/+$/g, '');
    const fileId = String(file.thumnAtchFileOrginlNm || (file.atchFileOrginlNm ? `${file.atchFileOrginlNm}.${file.fileExtnNm || 'jpg'}` : '')).trim();
    if (cours && fileId) {
      urls.push(`https://www.goodprice.go.kr/comm/showImageFile.do?fileCours=/bssh/${cours}/&fileId=${fileId}`);
    }
  }
  return urls;
}
