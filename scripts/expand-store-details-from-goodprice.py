#!/usr/bin/env python3
"""Expand store-hours.json from an official Good Price Stores CSV export.

The matcher deliberately requires multiple independent signals. It never accepts
a fuzzy name by itself, rejects conflicting phone numbers, and rejects close
ties. Convert the official XLS export to UTF-8 CSV before running this script.
"""

import argparse
import csv
import hashlib
import json
import re
import unicodedata
from collections import Counter, defaultdict
from difflib import SequenceMatcher


PROVINCES = {
    "서울특별시": "서울", "부산광역시": "부산", "대구광역시": "대구",
    "인천광역시": "인천", "광주광역시": "광주", "대전광역시": "대전",
    "울산광역시": "울산", "세종특별자치시": "세종", "경기도": "경기",
    "강원특별자치도": "강원", "강원도": "강원", "충청북도": "충북",
    "충청남도": "충남", "전북특별자치도": "전북", "전라북도": "전북",
    "전라남도": "전남", "경상북도": "경북", "경상남도": "경남",
    "제주특별자치도": "제주", "제주도": "제주",
}


def clean_text(value):
    return unicodedata.normalize("NFKC", str(value or "")).strip().lower()


def name_key(value):
    value = re.sub(r"(?:주식회사|유한회사|㈜|\(주\)|（주）)", "", clean_text(value))
    return re.sub(r"[^0-9a-z가-힣]", "", value)


def address_text(value):
    value = clean_text(value)
    for old, new in PROVINCES.items():
        value = value.replace(old, new, 1)
    return value


def address_key(value):
    value = address_text(value)
    value = re.sub(r"\([^)]*\)|（[^）]*）", " ", value)
    value = re.sub(r"\b(?:지하\s*)?\d+\s*층\b.*$", "", value)
    value = re.sub(r"\b\d+\s*호\b.*$", "", value)
    return re.sub(r"[^0-9a-z가-힣]", "", value)


def locality_key(value):
    tokens = re.findall(r"[0-9a-z가-힣]+", address_text(value))
    return "|".join(tokens[:2]) if tokens else ""


def phone_key(value):
    digits = re.sub(r"\D", "", str(value or ""))
    return digits if len(digits) >= 8 else ""


def building_key(value):
    value = re.sub(r"([가-힣0-9]+로)\s+(\d+번길)", r"\1\2", address_text(value))
    match = re.search(r"([가-힣0-9]+(?:대로|로|길))\s*(\d+(?:-\d+)?)", value)
    return "|".join(match.groups()) if match else ""


def similarity(left, right):
    return SequenceMatcher(None, left, right).ratio() if left and right else 0.0


def store_id(store):
    def original(value):
        return re.sub(r"\s+", " ", str(value or "").strip().lower())
    identity = "|".join(original(store.get(key)) for key in ("storeName", "address", "phoneNumber"))
    return "store_" + hashlib.sha256(identity.encode()).hexdigest()[:24]


def add_keys(row, source=False):
    row["_name"] = name_key(row["name"] if source else row["storeName"])
    row["_address"] = address_key(row["address"])
    row["_phone"] = phone_key(row["phone"] if source else row.get("phoneNumber"))
    row["_locality"] = locality_key(row["address"])
    row["_building"] = building_key(row["address"])


def read_source(path):
    with open(path, encoding="utf-8-sig", newline="") as handle:
        raw_rows = list(csv.reader(handle))
    if len(raw_rows) < 4:
        raise ValueError("The source CSV is empty or incomplete")
    headers = [value.strip() for value in raw_rows[2]]
    required = {"번호", "업종명", "업소명", "업소 전화번호", "주소", "주차여부", "포장여부"}
    if not required.issubset(headers):
        raise ValueError(f"Missing source columns: {sorted(required - set(headers))}")
    rows = []
    for values in raw_rows[3:]:
        raw = dict(zip(headers, values))
        if not str(raw.get("업소명", "")).strip():
            continue
        row_number = str(raw.get("번호", "")).removesuffix(".0")
        row = {
            "rowNumber": int(row_number),
            "name": str(raw.get("업소명", "")).strip(),
            "address": str(raw.get("주소", "")).strip(),
            "phone": str(raw.get("업소 전화번호", "")).strip(),
            "industry": str(raw.get("업종명", "")).strip(),
            "parkingYn": str(raw.get("주차여부", "")).strip().upper() == "O",
            "packingYn": str(raw.get("포장여부", "")).strip().upper() == "O",
            "currencies": [label for label, column in (
                ("지류형", "지역화폐(지류형)"), ("모바일형", "지역화폐(모바일형)"),
                ("카드형", "지역화폐(카드형)"),
            ) if str(raw.get(column, "")).strip().upper() == "O"],
        }
        add_keys(row, source=True)
        rows.append(row)
    return rows


def match(store, candidates):
    accepted = []
    for source in candidates:
        same_name = store["_name"] == source["_name"]
        same_address = store["_address"] == source["_address"]
        same_phone = bool(store["_phone"] and store["_phone"] == source["_phone"])
        phone_conflict = bool(store["_phone"] and source["_phone"] and store["_phone"] != source["_phone"])
        same_locality = bool(store["_locality"] and store["_locality"] == source["_locality"])
        same_building = bool(store["_building"] and store["_building"] == source["_building"])
        name_score = similarity(store["_name"], source["_name"])
        address_score = similarity(store["_address"], source["_address"])
        method = None
        if same_phone and same_name and same_locality and address_score >= 0.75:
            method = "PHONE_NAME_LOCALITY"
        elif same_name and same_address and not phone_conflict:
            method = "NAME_ADDRESS"
        elif same_phone and same_address and name_score >= 0.72:
            method = "PHONE_ADDRESS_SIMILAR_NAME"
        elif same_phone and same_locality and same_building and name_score >= 0.82:
            method = "PHONE_BUILDING_SIMILAR_NAME"
        elif same_name and same_locality and same_building and address_score >= 0.84 and not phone_conflict:
            method = "NAME_BUILDING_SIMILAR_ADDRESS"
        elif same_address and name_score >= 0.88 and not phone_conflict:
            method = "ADDRESS_SIMILAR_NAME"
        if method:
            score = (3 * same_phone + 2 * same_name + 2 * same_address + same_locality
                     + same_building + name_score + address_score)
            accepted.append((score, method, source, name_score, address_score))
    accepted.sort(key=lambda item: (-item[0], item[2]["rowNumber"]))
    if not accepted:
        return None, "NO_SAFE_MATCH"
    if len(accepted) > 1 and accepted[0][0] - accepted[1][0] < 0.75:
        return None, "AMBIGUOUS"
    return accepted[0], None


def currency_value(source):
    return f"지역화폐({', '.join(source['currencies'])})" if source["currencies"] else None


def make_record(store, source, method, checked_at):
    return {
        "storeId": store_id(store), "storeName": store["storeName"], "address": store["address"],
        "phoneNumber": store.get("phoneNumber"), "status": "SOURCE_VERIFIED",
        "text": "등록된 영업시간이 없어요.", "sourceName": "행정안전부 착한가격업소",
        "sourceUrl": "https://www.goodprice.go.kr/bssh/bsshInfo.do?bsshSn=0",
        "checkedAt": checked_at, "parkingYn": source["parkingYn"], "packingYn": source["packingYn"],
        "areaCurrency": currency_value(source), "matchMethod": method,
        "sourceRowNumber": source["rowNumber"], "matchedSourceName": source["name"],
        "matchedSourceAddress": source["address"], "matchedSourcePhoneNumber": source["phone"],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--snapshot", required=True)
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--source-csv", required=True)
    parser.add_argument("--source-xls-sha256")
    parser.add_argument("--checked-at", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--audit", required=True)
    args = parser.parse_args()

    with open(args.snapshot, encoding="utf-8") as handle:
        stores = json.load(handle)
    with open(args.catalog, encoding="utf-8") as handle:
        catalog = json.load(handle)
    sources = read_source(args.source_csv)
    existing_by_id = {row["storeId"]: row for row in catalog}
    if len(existing_by_id) != len(catalog):
        raise ValueError("The current catalog contains duplicate store IDs")
    for store in stores:
        add_keys(store)

    indices = {field: defaultdict(list) for field in ("_name", "_address", "_phone", "_building")}
    for source in sources:
        for field, index in indices.items():
            if source[field]:
                index[source[field]].append(source)

    additions, audit_matches = [], []
    scheduled = set(existing_by_id)
    counts, cross_check = Counter(), Counter()
    for store in stores:
        identifier = store_id(store)
        if identifier in existing_by_id:
            counts["ALREADY_ENRICHED"] += 1
        elif identifier in scheduled:
            counts["DUPLICATE_SNAPSHOT_ID"] += 1
            continue
        candidates = {}
        for field, index in indices.items():
            for source in index.get(store[field], []):
                candidates[source["rowNumber"]] = source
        result, rejection = match(store, candidates.values())
        if identifier in existing_by_id:
            if result is None:
                cross_check["NO_SAFE_MATCH"] += 1
            else:
                source = result[2]
                current = existing_by_id[identifier]
                cross_check["PARKING_AGREE" if current.get("parkingYn") == source["parkingYn"] else "PARKING_DIFFER"] += 1
                cross_check["PACKING_AGREE" if current.get("packingYn") == source["packingYn"] else "PACKING_DIFFER"] += 1
                current_currency = set(re.findall(r"지류형|모바일형|카드형", current.get("areaCurrency") or ""))
                cross_check["CURRENCY_AGREE" if current_currency == set(source["currencies"]) else "CURRENCY_DIFFER"] += 1
            continue
        if result is None:
            counts[rejection] += 1
            continue
        _, method, source, name_score, address_score = result
        counts[method] += 1
        additions.append(make_record(store, source, method, args.checked_at))
        scheduled.add(identifier)
        audit_matches.append({
            "storeId": identifier, "matchMethod": method,
            "store": {"name": store["storeName"], "address": store["address"], "phone": store.get("phoneNumber")},
            "source": {"rowNumber": source["rowNumber"], "name": source["name"],
                       "address": source["address"], "phone": source["phone"]},
            "nameSimilarity": round(name_score, 4), "addressSimilarity": round(address_score, 4),
        })

    additions.sort(key=lambda row: row["storeId"])
    output = catalog + additions
    if len({row["storeId"] for row in output}) != len(output):
        raise ValueError("Expansion would create duplicate store IDs")
    if len(sources) < 12_000 or len(stores) < 10_000 or len(additions) < 3_000:
        raise ValueError("Unexpected source or match coverage; refusing to write")
    for field in ("PARKING_DIFFER", "PACKING_DIFFER", "CURRENCY_DIFFER"):
        if cross_check[field]:
            raise ValueError(f"Existing-data cross-check failed: {field}={cross_check[field]}")

    summary = {
        "source": "행정안전부 착한가격업소 전국 엑셀 CSV 변환본",
        "sourceSha256": hashlib.sha256(open(args.source_csv, "rb").read()).hexdigest(),
        "sourceXlsSha256": args.source_xls_sha256,
        "checkedAt": args.checked_at, "sourceRows": len(sources), "snapshotRows": len(stores),
        "previousCoverage": len(catalog), "added": len(additions), "newCoverage": len(output),
        "coverageRate": round(len(output) / len({store_id(row) for row in stores}), 4),
        "unmatchedUniqueStores": len({store_id(row) for row in stores}) - len(output),
        "counts": dict(sorted(counts.items())), "existingCrossCheck": dict(sorted(cross_check.items())),
    }
    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(output, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    with open(args.audit, "w", encoding="utf-8") as handle:
        json.dump({"summary": summary, "matches": audit_matches}, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
