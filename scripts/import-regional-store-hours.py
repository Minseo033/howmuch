#!/usr/bin/env python3
"""Import reviewed regional Good Price Store CSVs without guessing store identities.

Download each official CSV into --source-dir with the filenames below. The
content hashes prevent a silent import if a provider replaces its file.
Dry-run by default; --write changes only existing no-hours catalog entries.
"""

import argparse
import csv
import hashlib
import importlib.util
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
NO_HOURS = "등록된 영업시간이 없어요."
SOURCES = [
    # Newer, smaller local releases take precedence over older broad releases.
    dict(file="howmuch_sancheong_20260805.csv", sha="822aadee3b064746d9366dd9eed67a3a4e3fbd575fa2caedb7bd89245f51d29e", rows=13,
         name="경상남도 산청군 착한가격업소", id="15089937", date="2026-08-05", name_col="업소명", address_col="소재지", phone_col="연락처",
         start_col="영업시작시간", end_col="영업종료시간"),
    dict(file="howmuch_donghae_20260706.csv", sha="b2a4601aa698bd742d07a5fc1939ca5714a86b6a5cf93bc99a8b97cbbe23802a", rows=57,
         name="강원특별자치도 동해시 착한가격업소", id="3077962", date="2026-07-06", name_col="업소명", address_col="도로명주소", phone_col="연락처",
         hours_col="영업시간"),
    dict(file="howmuch_ulsan_namgu_20260512.csv", sha="9a8303aacf78d23a9155f3d18bbe36df57544e30e24abd16cfd0571eaea18726", rows=82,
         name="울산광역시 남구 착한가격업소", id="3069400", date="2026-05-12", name_col="업소명", address_col="소재지도로명주소", phone_col="연락처",
         hours_col="영업시간"),
    dict(file="howmuch_dongducheon_20260313.csv", sha="c169c2bad33e0c16140c94224042415c5a897169ed736895b6019ca6e4e1b159", rows=24,
         name="경기도 동두천시 착한가격업소", id="3072002", date="2026-03-13", name_col="상호명", address_col="소재지도로명주소", phone_col="전화번호",
         start_col="영업시간시간", end_col="영업종료시간"),
    dict(file="howmuch_ulsan_20250707.csv", sha="f2805e71eb034869336aa79dd57461721200759ee3ba78c537319a9c7803be85", rows=108,
         name="울산광역시 착한가격업소", id="15083262", date="2025-07-07", name_col="업소명", address_col="주소", phone_col="연락처",
         hours_col="영업시간"),
]


def matcher():
    spec = importlib.util.spec_from_file_location(
        "goodprice_matcher", ROOT / "scripts/expand-store-details-from-goodprice.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def valid_hours(text):
    if not re.fullmatch(r"\d{1,2}:\d{2}\s*~\s*\d{1,2}:\d{2}", text):
        return False
    return all(int(hour) <= 24 and int(minute) < 60 for hour, minute in re.findall(r"(\d{1,2}):(\d{2})", text))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    catalog_path = ROOT / "howmuch_backend/src/main/resources/store-hours.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    stores = json.loads((ROOT / "howmuch_backend/src/main/resources/stores-snapshot.json").read_text(encoding="utf-8"))
    match = matcher()
    store_index = defaultdict(list)
    for store in stores:
        store_index[(match.name_key(store["storeName"]), match.address_key(store["address"]))].append(store)
    catalog_by_id = {entry["storeId"]: entry for entry in catalog}
    summary = []
    for source in SOURCES:
        raw = (args.source_dir / source["file"]).read_bytes()
        if hashlib.sha256(raw).hexdigest() != source["sha"]:
            raise ValueError(f"Official source SHA-256 changed: {source['file']}")
        rows = list(csv.DictReader(raw.decode("cp949").splitlines()))
        if len(rows) != source["rows"]:
            raise ValueError(f"Unexpected source row count: {source['file']}")
        keys = Counter((match.name_key(row[source["name_col"]]), match.address_key(row[source["address_col"]])) for row in rows)
        counts = Counter()
        for row in rows:
            key = (match.name_key(row[source["name_col"]]), match.address_key(row[source["address_col"]]))
            if not key[0] or not key[1] or keys[key] != 1 or len(store_index[key]) != 1:
                counts["unmatched"] += 1
                continue
            store = store_index[key][0]
            source_phone = match.phone_key(row[source["phone_col"]])
            store_phone = match.phone_key(store.get("phoneNumber"))
            if source_phone and store_phone and source_phone != store_phone:
                counts["phoneConflict"] += 1
                continue
            entry = catalog_by_id.get(match.store_id(store))
            if entry is None:
                counts["notInCatalog"] += 1
                continue
            hours = (row[source["hours_col"]].strip() if "hours_col" in source else
                     f"{row[source['start_col']].strip()}~{row[source['end_col']].strip()}")
            if not valid_hours(hours):
                counts["invalidHours"] += 1
                continue
            if entry["text"] != NO_HOURS:
                counts["alreadyHasHours"] += 1
                continue
            entry.update(text=hours, sourceName=source["name"],
                         sourceUrl=f"https://www.data.go.kr/data/{source['id']}/fileData.do",
                         checkedAt=source["date"])
            counts["added"] += 1
        summary.append({"source": source["name"], "date": source["date"], "sourceRows": len(rows), **counts})
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    if args.write:
        catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
