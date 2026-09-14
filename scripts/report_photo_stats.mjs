import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const hours = JSON.parse(await readFile(path.join(root, 'howmuch_backend/src/main/resources/store-hours.json'), 'utf8'));
const withPhotos = hours.filter(h => h.imageUrls && h.imageUrls.length > 0);

const pt = withPhotos.filter(h => (h.address || '').includes('평택'));
const school = withPhotos.filter(h => /구로구|영등포구|양천구|금천구/.test(h.address || ''));
const seoulCore = withPhotos.filter(h => (h.address || '').startsWith('서울특별시') && /종로구|중구|강남구|마포구|서대문구|용산구/.test(h.address || ''));
const other = withPhotos.filter(h => !pt.includes(h) && !school.includes(h) && !seoulCore.includes(h));

console.log(JSON.stringify({
  totalStoresInCatalog: hours.length,
  totalStoresWithPhotos: withPhotos.length,
  pyeongtaek: pt.length,
  schoolArea: school.length,
  seoulCore: seoulCore.length,
  otherAreas: other.length
}, null, 2));
