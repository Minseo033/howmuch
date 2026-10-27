// 착한가격업소 사진을 영업시간 카탈로그 기록에 합칠 때 쓰는 순수 함수입니다.
// merge-region-photos.mjs가 씁니다.

export const GOODPRICE_SOURCE_NAME = '행정안전부 착한가격업소';

/**
 * 새 사진이 있을 때만 기록을 바꿉니다(WEB-ADM-10).
 * - 이미 가진 사진뿐이면 아무것도 바꾸지 않아, 다시 실행해도 결과가 같습니다.
 * - 출처·확인일은 영업시간의 출처를 뜻하므로, 착한가격업소가 출처인 기록에서만 갱신합니다.
 *   지자체 자료처럼 다른 출처의 기록은 사진만 더하고 출처·확인일을 그대로 둡니다.
 * @returns {boolean} 기록이 바뀌었는지
 */
export function applyPhotoMatch(entry, { sourceUrl, urls, checkedAt }) {
  const current = Array.isArray(entry.imageUrls) ? entry.imageUrls : [];
  const merged = [...new Set([...current, ...(urls || [])])];
  if (merged.length === current.length) return false;
  entry.imageUrls = merged;
  if (!entry.sourceName || entry.sourceName === GOODPRICE_SOURCE_NAME) {
    entry.sourceName = GOODPRICE_SOURCE_NAME;
    entry.sourceUrl = sourceUrl;
    entry.checkedAt = checkedAt;
  }
  return true;
}
