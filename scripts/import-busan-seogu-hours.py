#!/usr/bin/env python3
"""Import only unique name + normalized-address matches from the public Seo-gu CSV.

Source: https://www.data.go.kr/data/15051967/fileData.do (2026-06-11)
Download the original CSV, then run with --source-csv PATH. Dry-run by default.
"""

import argparse
import csv
import hashlib
import importlib.util
import json
import sys
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_URL = "https://www.data.go.kr/data/15051967/fileData.do"
SOURCE_SHA256 = "2a83ffb7d0e43379c21a4c6a382c2158e9edffc2b22d21071814fcb145c32c9c"
NO_HOURS = "등록된 영업시간이 없어요."
SOURCE_NAME = "부산광역시 서구 착한가격업소"
SOURCE_DATE = "2026-06-11"
sys.dont_write_bytecode = True


def helpers():
    spec = importlib.util.spec_from_file_location(
        "goodprice_matcher", ROOT / "scripts/expand-store-details-from-goodprice.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def select_updates(source_bytes, stores, catalog):
    if hashlib.sha256(source_bytes).hexdigest() != SOURCE_SHA256:
        raise ValueError("Source CSV SHA-256 differs from the reviewed 2026-06-11 file")
    rows = list(csv.DictReader(source_bytes.decode("cp949").splitlines()))
    if len(rows) != 74:
        raise ValueError(f"Expected 74 source rows, got {len(rows)}")
    match = helpers()
    by_identity = defaultdict(list)
    for store in stores:
        by_identity[(match.name_key(store["storeName"]), match.address_key(store["address"]))].append(store)
    catalog_by_id = {entry["storeId"]: entry for entry in catalog}
    updates = []
    already_applied = 0
    unmatched = []
    for row in rows:
        key = (match.name_key(row["업소명"]), match.address_key(row["소재지주소"]))
        candidates = by_identity[key]
        # No name-only, address-only, or ambiguous-building matches are accepted.
        if len(candidates) != 1 or not key[0] or not key[1]:
            unmatched.append(row["업소명"])
            continue
        store = candidates[0]
        entry = catalog_by_id.get(match.store_id(store))
        if entry is None:
            raise ValueError(f"Matched store missing from reviewed catalog: {store['storeName']}")
        hours = row["영업시간"].strip()
        if not hours or len(hours) > 1000 or "<" in hours or ">" in hours:
            raise ValueError(f"Invalid hours for {store['storeName']}")
        if entry["text"] not in (NO_HOURS, hours):
            raise ValueError(f"Existing hours must not be overwritten: {store['storeName']}")
        if entry["text"] == NO_HOURS:
            updates.append((entry, hours))
        else:
            if (entry["sourceName"], entry["sourceUrl"], entry["checkedAt"]) != (SOURCE_NAME, SOURCE_URL, SOURCE_DATE):
                raise ValueError(f"Existing hours have an unrelated source: {store['storeName']}")
            already_applied += 1
    if len(updates) + already_applied != 59 or len(unmatched) != 15:
        raise ValueError(f"Unexpected match coverage: {len(updates)} updates, {already_applied} existing, {len(unmatched)} unmatched")
    return updates, already_applied, unmatched


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-csv", required=True, type=Path)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    catalog_path = ROOT / "howmuch_backend/src/main/resources/store-hours.json"
    stores_path = ROOT / "howmuch_backend/src/main/resources/stores-snapshot.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    stores = json.loads(stores_path.read_text(encoding="utf-8"))
    updates, already_applied, unmatched = select_updates(args.source_csv.read_bytes(), stores, catalog)
    print(json.dumps({"sourceRows": 74, "matchedNewHours": len(updates),
                      "alreadyApplied": already_applied, "unmatched": len(unmatched)}, ensure_ascii=False))
    if args.write and updates:
        for entry, hours in updates:
            entry.update(text=hours, sourceName=SOURCE_NAME, sourceUrl=SOURCE_URL, checkedAt=SOURCE_DATE)
        catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
