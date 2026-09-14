import importlib.util
import pathlib
import unittest


SCRIPT = pathlib.Path(__file__).with_name("expand-store-details-from-goodprice.py")
SPEC = importlib.util.spec_from_file_location("goodprice_matcher", SCRIPT)
MATCHER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MATCHER)


def prepared(name, address, phone, source=False, row_number=1):
    row = {"address": address}
    if source:
        row.update({"name": name, "phone": phone, "rowNumber": row_number})
    else:
        row.update({"storeName": name, "phoneNumber": phone})
    MATCHER.add_keys(row, source=source)
    return row


class GoodpriceMatcherTest(unittest.TestCase):
    def test_accepts_formatting_differences_with_phone_name_and_locality(self):
        store = prepared("0시50분", "대전광역시 중구 대종로 504, 1층 (은행동)", "042-524-5816")
        source = prepared("0시50분", "대전광역시 중구 대종로 504 1층(은행동)", "042-524-5816", True)
        result, rejection = MATCHER.match(store, [source])
        self.assertIsNone(rejection)
        self.assertEqual(result[1], "PHONE_NAME_LOCALITY")

    def test_rejects_conflicting_phone_even_when_name_and_address_match(self):
        store = prepared("동네식당", "서울특별시 강동구 천중로 73", "02-123-4567")
        source = prepared("동네식당", "서울특별시 강동구 천중로 73", "02-999-9999", True)
        result, rejection = MATCHER.match(store, [source])
        self.assertIsNone(result)
        self.assertEqual(rejection, "NO_SAFE_MATCH")

    def test_accepts_a_small_name_typo_only_at_the_same_address(self):
        store = prepared("3000냥국밥집", "부산광역시 부산진구 새싹로 16-1, 1층", "")
        source = prepared("3000천냥국밥집", "부산광역시 부산진구 새싹로 16-1 1층", "", True)
        result, rejection = MATCHER.match(store, [source])
        self.assertIsNone(rejection)
        self.assertEqual(result[1], "ADDRESS_SIMILAR_NAME")

    def test_rejects_a_fuzzy_name_without_phone_or_address_evidence(self):
        store = prepared("한결식당", "서울특별시 강남구 테헤란로 10", "")
        source = prepared("한결한식", "서울특별시 강남구 역삼로 20", "", True)
        result, rejection = MATCHER.match(store, [source])
        self.assertIsNone(result)
        self.assertEqual(rejection, "NO_SAFE_MATCH")

    def test_accepts_exact_name_and_road_number_with_extra_source_description(self):
        store = prepared("가야떡방앗간", "경상남도 합천군 가야면 가야시장로 54-1", "")
        source = prepared("가야떡방앗간", "경상남도 합천군 가야면 가야시장로 54-1 가야떡방앗간", "", True)
        result, rejection = MATCHER.match(store, [source])
        self.assertIsNone(rejection)
        self.assertEqual(result[1], "NAME_BUILDING_SIMILAR_ADDRESS")

    def test_rejects_a_close_tie_between_multiple_candidates(self):
        store = prepared("우리식당", "서울특별시 강동구 천중로 73", "")
        first = prepared("우리식당", "서울특별시 강동구 천중로 73 1층", "", True, 1)
        second = prepared("우리식당", "서울특별시 강동구 천중로 73 2층", "", True, 2)
        result, rejection = MATCHER.match(store, [first, second])
        self.assertIsNone(result)
        self.assertEqual(rejection, "AMBIGUOUS")


if __name__ == "__main__":
    unittest.main()
