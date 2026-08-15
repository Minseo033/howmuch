package com.howmuch.service;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 메뉴/품목별 시장 평균가(기준가) 테이블 — 절약 금액 계산의 비교 기준.
 * 절약 금액 = 기준가(시장가) − 실제 결제가 (하한 0).
 *
 * 근거: 한국소비자원 참가격(www.price.go.kr) 품목별 월별 가격을 참고한 2025년 근사치.
 * ⚠️ 참가격은 매월 변동되므로 주기적 갱신 필요. 1인분/1회 이용 기준으로 정규화했고,
 *    삼겹살·불고기 등 인분 수가 다른 품목은 1인분 환산값이라 오차가 있을 수 있음.
 */
public final class ReferencePrices {

    private ReferencePrices() {}

    /** 품목 키워드 → 기준가(원). LinkedHashMap 순서 = 매칭 우선순위 (앞쪽 우선) */
    private static final Map<String, Long> MENU_PRICES = new LinkedHashMap<>() {{
        // ── 외식 (참가격 품목 + 대표 메뉴) ──
        put("김치찌개", 9000L);
        put("된장찌개", 9000L);
        put("순두부", 9000L);
        put("부대찌개", 10000L);
        put("갈비탕", 15000L);
        put("설렁탕", 11000L);
        put("곰탕", 11000L);
        put("냉면", 11500L);
        put("비빔밥", 10500L);
        put("불고기", 16000L);
        put("삼겹살", 20000L);   // 1인분(200g) 환산
        put("갈비", 25000L);
        put("보쌈", 18000L);
        put("족발", 18000L);
        put("짜장", 7500L);
        put("자장", 7500L);
        put("짬뽕", 9000L);
        put("탕수육", 15000L);
        put("볶음밥", 9000L);
        put("칼국수", 9000L);
        put("수제비", 9000L);
        put("김밥", 4000L);
        put("라면", 5000L);
        put("떡볶이", 5000L);
        put("순대", 7000L);
        put("돈까스", 11000L);
        put("돈가스", 11000L);
        put("초밥", 20000L);
        put("광어", 25000L);
        put("우럭", 25000L);
        put("회", 25000L);
        put("파스타", 15000L);
        put("피자", 20000L);
        put("치킨", 20000L);
        put("햄버거", 8000L);
        put("버거", 8000L);
        put("샌드위치", 7000L);
        put("아메리칸", 5000L);
        put("라떼", 5500L);
        put("커피", 5000L);
        put("케이크", 6000L);
        put("빵", 4000L);
        // ── 생활 서비스 (참가격 서비스 품목) ──
        put("커트", 14000L);
        put("컷", 14000L);
        put("펌", 60000L);
        put("염색", 50000L);
        put("이발", 12000L);
        put("이용료", 12000L);
        put("목욕", 11000L);
        put("사우나", 11000L);
        put("찜질", 12000L);
        put("와이셔츠", 3000L);
        put("셔츠", 3000L);
        put("정장", 9000L);
        put("코트", 12000L);
        put("이불", 10000L);
        put("숙박", 60000L);
        put("모텔", 60000L);
    }};

    /** 공공데이터 industry 값 → 카테고리 평균가 (메뉴 미매칭 시 폼백 기본값) */
    private static final Map<String, Long> CATEGORY_AVG = new LinkedHashMap<>() {{
        put("한식", 10000L);
        put("중식", 9000L);
        put("일식", 15000L);
        put("양식", 15000L);
        put("기타요식업", 7000L);
        put("미용업", 14000L);
        put("이용업", 12000L);
        put("세탁업", 6000L);
        put("목욕업", 11000L);
        put("숙박업", 60000L);
        put("기타비요식업", 10000L);
    }};

    private static final long DEFAULT_PRICE = 10_000L;

    /** 메뉴/품목명에서 기준가 매칭 (공백 제거 후 부분 문자열, 먼저 매칭된 항목 우선). 없으면 null */
    public static Long matchMenuPrice(String menu) {
        if (menu == null || menu.isBlank()) return null;
        String normalized = menu.replaceAll("\\s+", "");
        for (Map.Entry<String, Long> entry : MENU_PRICES.entrySet()) {
            if (normalized.contains(entry.getKey())) {
                return entry.getValue();
            }
        }
        return null;
    }

    /** 업종 → 카테고리 평균가 (부분 문자열 매칭, 없으면 기본값) */
    public static long categoryAverage(String industry) {
        if (industry != null) {
            for (Map.Entry<String, Long> entry : CATEGORY_AVG.entrySet()) {
                if (industry.contains(entry.getKey())) {
                    return entry.getValue();
                }
            }
        }
        return DEFAULT_PRICE;
    }

    /** 최종 기준가: 메뉴 매칭 우선 → 업종 평균 → 기본값 */
    public static long referencePrice(String menu, String industry) {
        Long menuPrice = matchMenuPrice(menu);
        return menuPrice != null ? menuPrice : categoryAverage(industry);
    }

    /** 절약 금액 = 기준가 − 결제가 (하한 0) */
    public static long savedAmount(String menu, String industry, long price) {
        return Math.max(0L, referencePrice(menu, industry) - price);
    }
}
