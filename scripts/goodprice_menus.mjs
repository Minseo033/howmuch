/**
 * 착한가격업소 상세의 메뉴 가격(menuPc)을 확정 금액 문자열로 바꿉니다(WEB-ADM-12).
 * 빈 값·null·숫자가 아닌 값은 null입니다. 원본에는 무료 표시가 없으므로 0원도 확정 가격으로
 * 보지 않습니다(서비스는 무료를 명시한 메뉴만 0원으로 허용합니다).
 */
export function confirmedMenuPrice(raw) {
  if (raw === null || raw === undefined) return null;
  const text = String(raw).trim().replace(/[,\s]/g, '').replace(/원$/, '');
  if (!/^\d{1,7}$/.test(text)) return null;
  const value = Number(text);
  return value > 0 ? String(value) : null;
}
