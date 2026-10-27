"""Regression tests for the regional store-hours importers.

Run: python3 scripts/import-store-hours.test.py
"""

import importlib.util
import json
import pathlib
import sys
import unittest
from collections import defaultdict


sys.dont_write_bytecode = True
SCRIPTS = pathlib.Path(__file__).resolve().parent
RESOURCES = SCRIPTS.parent / "howmuch_backend/src/main/resources"
NO_HOURS = "등록된 영업시간이 없어요."


def load(stem):
    spec = importlib.util.spec_from_file_location(stem.replace("-", "_"), SCRIPTS / f"{stem}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


BUSAN = load("import-busan-seogu-hours")
REGIONAL = load("import-regional-store-hours")
RECENT = load("import-recent-municipal-hours")
MATCH = load("expand-store-details-from-goodprice")


def snapshot_store(name, address, province, district, phone=None):
    return {"storeName": name, "address": address, "phoneNumber": phone,
            "cityProvince": province, "cityDistrict": district}


def empty_entry(store):
    return {"storeId": MATCH.store_id(store), "storeName": store["storeName"], "text": NO_HOURS,
            "sourceName": "행정안전부 착한가격업소", "sourceUrl": "https://www.goodprice.go.kr/", "checkedAt": "2026-06-30"}


def configured(sources, field, value):
    return next(source for source in sources if source[field] == value)


def configured_regions():
    yield BUSAN.SOURCE_NAME, BUSAN.PROVINCE, BUSAN.DISTRICT, BUSAN.in_region
    for source in REGIONAL.SOURCES:
        yield source["name"], source["province"], source["district"], lambda store, s=source: REGIONAL.in_region(store, s)
    for source in RECENT.SOURCES:
        yield source["provider"], source["province"], source["district"], lambda store, s=source: RECENT.in_region(store, s)


class CsvLineBreakTest(unittest.TestCase):
    RAW = ('업소명,소재지주소,영업시간\r\n'
           '가나식당,"부산광역시 서구 구덕로 1,\n2층","11:00~15:00\r\n17:00~21:00"\r\n'
           '다라분식,부산광역시 서구 대신로 2,09:00~18:00\r\n').encode("cp949")

    def test_quoted_line_breaks_stay_inside_their_cell(self):
        for module in (BUSAN, REGIONAL):
            with self.subTest(module=module.__name__):
                rows = module.read_csv_rows(self.RAW)
                self.assertEqual(len(rows), 2)
                self.assertEqual(rows[0]["소재지주소"], "부산광역시 서구 구덕로 1,\n2층")
                self.assertEqual(rows[0]["영업시간"], "11:00~15:00\n17:00~21:00")
                self.assertEqual(rows[1], {"업소명": "다라분식", "소재지주소": "부산광역시 서구 대신로 2", "영업시간": "09:00~18:00"})


class BusanRegionTest(unittest.TestCase):
    ADDRESS = "부산광역시 서구 구덕로 1, 2층 (동대신동)"
    LOCAL = snapshot_store("가나식당", ADDRESS, "부산광역시", "서구")
    # Same name and address text, but the snapshot places this store in another district.
    OUTSIDE = snapshot_store("가나식당", ADDRESS, "부산광역시", "중구", "051-000-0000")

    def test_store_outside_seo_gu_is_never_a_candidate(self):
        row = {"업소명": "가나식당", "소재지주소": self.ADDRESS, "영업시간": "11:00~21:00"}
        result = BUSAN.match_rows([row], [self.OUTSIDE], [empty_entry(self.OUTSIDE)])
        self.assertEqual(result, ([], 0, ["가나식당"]))

    def test_seo_gu_store_matches_an_address_cell_split_across_lines(self):
        row = {"업소명": "가나식당", "소재지주소": "부산광역시 서구 구덕로 1, 2층\n(동대신동)", "영업시간": "11:00~21:00"}
        catalog = [empty_entry(self.LOCAL), empty_entry(self.OUTSIDE)]
        updates, already_applied, unmatched = BUSAN.match_rows([row], [self.LOCAL, self.OUTSIDE], catalog)
        self.assertEqual([(entry["storeId"], hours) for entry, hours in updates], [(MATCH.store_id(self.LOCAL), "11:00~21:00")])
        self.assertEqual((already_applied, unmatched), (0, []))


class RegionalRegionTest(unittest.TestCase):
    def run_source(self, name, row, stores):
        catalog_by_id = {MATCH.store_id(store): empty_entry(store) for store in stores}
        counts = REGIONAL.import_rows(configured(REGIONAL.SOURCES, "name", name), [row], stores, catalog_by_id, MATCH)
        return dict(counts), {store_id: entry["text"] for store_id, entry in catalog_by_id.items()}

    def test_district_source_ignores_stores_outside_its_district(self):
        address = "울산광역시 남구 삼산로 10"
        local = snapshot_store("다라분식", address, "울산광역시", "남구")
        outside = snapshot_store("다라분식", address, "울산광역시", "중구", "052-000-0000")
        row = {"업소명": "다라분식", "소재지도로명주소": address, "연락처": "", "영업시간": "09:00~18:00"}
        self.assertEqual(self.run_source("울산광역시 남구 착한가격업소", row, [outside]),
                         ({"unmatched": 1}, {MATCH.store_id(outside): NO_HOURS}))
        self.assertEqual(self.run_source("울산광역시 남구 착한가격업소", row, [local, outside]),
                         ({"added": 1}, {MATCH.store_id(local): "09:00~18:00", MATCH.store_id(outside): NO_HOURS}))

    def test_province_wide_source_accepts_any_district_of_its_province_only(self):
        address = "울산광역시 중구 성남로 5"
        local = snapshot_store("마바국밥", address, "울산광역시", "중구")
        outside = snapshot_store("마바국밥", address, "부산광역시", "중구", "051-111-1111")
        row = {"업소명": "마바국밥", "주소": address, "연락처": "", "영업시간": "10:00~20:00"}
        self.assertEqual(self.run_source("울산광역시 착한가격업소", row, [local, outside]),
                         ({"added": 1}, {MATCH.store_id(local): "10:00~20:00", MATCH.store_id(outside): NO_HOURS}))

    def test_address_cell_split_across_lines_still_matches(self):
        local = snapshot_store("사아떡집", "경기도 동두천시 중앙로 20, 1층 (생연동)", "경기도", "동두천시")
        row = {"상호명": "사아떡집", "소재지도로명주소": "경기도 동두천시 중앙로 20, 1층\n(생연동)", "전화번호": "",
               "영업시간시간": "08:00", "영업종료시간": "19:00"}
        self.assertEqual(self.run_source("경기도 동두천시 착한가격업소", row, [local]),
                         ({"added": 1}, {MATCH.store_id(local): "08:00~19:00"}))


class RecentMunicipalRegionTest(unittest.TestCase):
    SOURCE = configured(RECENT.SOURCES, "provider", "울산광역시 북구 착한가격업소")
    ROW = ("행복식당", "울산광역시 북구 중앙로 12", "", "10:00~20:00")
    LOCAL = snapshot_store("행복식당", "울산광역시 북구 중앙로 12, 1층", "울산광역시", "북구")
    # Same name, road name, and building number in another municipality.
    ELSEWHERE = snapshot_store("행복식당", "경상북도 경주시 중앙로 12", "경상북도", "경주시")

    def run_source(self, stores, catalog):
        by_id = {entry["storeId"]: entry for entry in catalog}
        return dict(RECENT.import_rows(self.SOURCE, [self.ROW], stores, catalog, by_id, MATCH))

    def test_same_name_and_building_in_another_municipality_is_not_matched(self):
        catalog = []
        self.assertEqual(self.run_source([self.ELSEWHERE], catalog), {"unmatched": 1})
        self.assertEqual(catalog, [])

    def test_store_in_the_source_municipality_is_matched(self):
        catalog = [empty_entry(self.LOCAL), empty_entry(self.ELSEWHERE)]
        self.assertEqual(self.run_source([self.LOCAL, self.ELSEWHERE], catalog), {"added": 1})
        self.assertEqual([(entry["text"], entry["sourceName"]) for entry in catalog],
                         [("10:00~20:00", "울산광역시 북구 착한가격업소"), (NO_HOURS, "행정안전부 착한가격업소")])


class ConfiguredRegionTest(unittest.TestCase):
    def test_region_fields_match_the_provider_name(self):
        for name, province, district, _ in configured_regions():
            with self.subTest(name=name):
                self.assertEqual(name, " ".join(filter(None, (province, district, "착한가격업소"))))

    def test_current_catalog_entries_of_each_source_lie_in_its_region(self):
        stores_by_id = defaultdict(list)
        for store in json.loads((RESOURCES / "stores-snapshot.json").read_text(encoding="utf-8")):
            stores_by_id[MATCH.store_id(store)].append(store)
        catalog = json.loads((RESOURCES / "store-hours.json").read_text(encoding="utf-8"))
        for name, _, _, in_region in configured_regions():
            with self.subTest(name=name):
                stores = [store for entry in catalog if entry["sourceName"] == name
                          for store in stores_by_id.get(entry["storeId"], [])]
                self.assertTrue(stores, "no current catalog entry from this source maps to a snapshot store")
                self.assertEqual([store["address"] for store in stores if not in_region(store)], [])


if __name__ == "__main__":
    unittest.main()
