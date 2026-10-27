// 착한가격업소 원본 행과 서비스 매장의 주소가 같은 곳인지 판정합니다.
// merge-region-photos.mjs와 audit-goodprice-catalog-gap.mjs가 함께 씁니다(WEB-ADM-11).
// 시·도 접두어, 띄어쓰기, 쉼표·괄호 뒤의 층·호수 차이는 같은 주소로 보지만
// 건물번호는 통째로 같아야 합니다('중앙로 3' ≠ '중앙로 35' ≠ '중앙로 3-1' ≠ '중앙로3번길').

const FULL_PROVINCES = [
  '서울특별시', '서울시', '부산광역시', '대구광역시', '인천광역시', '광주광역시', '대전광역시', '울산광역시',
  '세종특별자치시', '세종시', '경기도', '강원특별자치도', '강원도', '충청북도', '충청남도', '전라북도',
  '전북특별자치도', '전라남도', '경상북도', '경상남도', '제주특별자치도', '제주도', '전남광주통합특별시',
];
const SHORT_PROVINCES = ['서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종', '경기', '강원',
  '충북', '충남', '전북', '전남', '경북', '경남', '제주'];
// 줄임말(예: '광주')은 뒤에 띄어쓰기가 있을 때만 시·도로 봅니다. '광주시'(경기도) 같은 이름을 자르지 않기 위해서입니다.
const PROVINCE_PREFIX = new RegExp(`^(?:(${FULL_PROVINCES.join('|')})\\s*|(${SHORT_PROVINCES.join('|')})\\s+)`);
const PROVINCE_GROUPS = new Map([
  ['서울', ['서울특별시', '서울시', '서울']],
  ['부산', ['부산광역시', '부산']],
  ['대구', ['대구광역시', '대구']],
  ['인천', ['인천광역시', '인천']],
  ['대전', ['대전광역시', '대전']],
  ['울산', ['울산광역시', '울산']],
  ['세종', ['세종특별자치시', '세종시', '세종']],
  ['경기', ['경기도', '경기']],
  ['강원', ['강원특별자치도', '강원도', '강원']],
  ['충북', ['충청북도', '충북']],
  ['충남', ['충청남도', '충남']],
  ['전북', ['전라북도', '전북특별자치도', '전북']],
  // 광주·전남은 통합 명칭과 옛 명칭이 원본마다 섞여 있어 한 지역으로 봅니다.
  ['전남광주', ['광주광역시', '광주', '전라남도', '전남', '전남광주통합특별시']],
  ['경북', ['경상북도', '경북']],
  ['경남', ['경상남도', '경남']],
  ['제주', ['제주특별자치도', '제주도', '제주']],
]);
const PROVINCE_BY_NAME = new Map([...PROVINCE_GROUPS].flatMap(([group, names]) => names.map((name) => [name, group])));

export function normalizeText(value) {
  let decoded = String(value ?? '');
  // 원본이 HTML 이스케이프를 여러 겹 씌워 보내는 경우가 있어 반복해서 풉니다.
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

const mainPart = (value) => normalizeText(String(value ?? '').split(/[,(]/)[0]);

/** 주소 앞의 시·도를 같은 지역끼리 묶은 이름으로 돌려줍니다. 없으면 null입니다. */
export function provinceOf(value) {
  const match = mainPart(value).match(PROVINCE_PREFIX);
  return match ? PROVINCE_BY_NAME.get(match[1] || match[2]) ?? null : null;
}

// 포함·일치 비교용 키: 띄어쓰기는 지우되 숫자 사이의 띄어쓰기는 '|'로 남겨 '35 1층'이 '351층'으로
// 붙지 않게 하고, 부번의 '-'는 남겨 '3-1'이 '31'과 같아지지 않게 합니다.
const boundaryKey = (text) => text
  .replace(/(\d)\s*-\s*(?=\d)/g, '$1-')
  .replace(/(\d)\s+(?=\d)/g, '$1|')
  .replace(/[\s.,()_/]/g, '');
// 끝부분 비교용 키: 기존 규칙과 같게 기호를 모두 지웁니다. 끝 6글자 창의 의미가 바뀌지 않게 하기 위해서입니다.
const looseKey = (text) => text.replace(/[\s.,()\-_/]/g, '');

function addressKeys(value, compact) {
  const main = mainPart(value);
  return [...new Set([compact(main), compact(main.replace(PROVINCE_PREFIX, ''))].filter(Boolean))];
}

function buildingNumbers(value) {
  return [...String(value ?? '').matchAll(/(?:^|\D)(\d{1,5})(?:-\d{1,5})?(?=\D|$)/g)].map((match) => match[1]);
}

// 숫자로 끝나는 짧은 주소가 긴 주소 안에 있어도, 그 뒤가 숫자·부번(-숫자)·도로명(번길·길)으로
// 이어지면 건물번호나 도로가 다른 주소입니다.
function containsAddress(longer, shorter) {
  if (!shorter || shorter.length > longer.length) return false;
  if (!/\d$/.test(shorter)) return longer.includes(shorter);
  for (let index = longer.indexOf(shorter); index !== -1; index = longer.indexOf(shorter, index + 1)) {
    if (!/^(?:\d|-\d|번길|길)/.test(longer.slice(index + shorter.length))) return true;
  }
  return false;
}

export function addressMatches(left, right) {
  const leftProvince = provinceOf(left);
  const rightProvince = provinceOf(right);
  // 두 주소에 시·도가 모두 적혀 있으면 같은 시·도여야 합니다(부산 북구 ≠ 울산 북구).
  if (leftProvince && rightProvince && leftProvince !== rightProvince) return false;
  const leftKeys = addressKeys(left, boundaryKey);
  const rightKeys = addressKeys(right, boundaryKey);
  if (leftKeys[0] && rightKeys[0]
      && (containsAddress(leftKeys[0], rightKeys[0]) || containsAddress(rightKeys[0], leftKeys[0]))) return true;
  if (leftKeys[1] && rightKeys[1] && leftKeys[1] === rightKeys[1]) return true;
  // 시·군 표기만 조금 다른 경우('수원'·'수원시')는 같은 건물번호와 같은 끝부분(도로명·번호)에 더해
  // 시·군 이름 앞 두 글자까지 같을 때만 인정합니다(수원 중앙로 35 ≠ 안양 중앙로 35).
  const numbers = buildingNumbers(left);
  const otherNumbers = buildingNumbers(right);
  const leftLocal = addressKeys(left, looseKey).at(-1) ?? '';
  const rightLocal = addressKeys(right, looseKey).at(-1) ?? '';
  return numbers.length > 0 && numbers.some((number) => otherNumbers.includes(number))
    && leftLocal.slice(-6) === rightLocal.slice(-6)
    && leftLocal.slice(0, 2) === rightLocal.slice(0, 2);
}
