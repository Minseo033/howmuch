#!/usr/bin/env python3
"""Dry-run import of recent municipal Good Price Store hours.

Download the four official sources named below into --source-dir. Exact file
hashes, unique name+street-number matches, and phone consistency are required.
Existing hours and unrelated store details are never overwritten.
"""

import argparse
import hashlib
import html
import importlib.util
import json
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
from collections import Counter, defaultdict
from pathlib import Path


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
NO_HOURS = "등록된 영업시간이 없어요."
SOURCES = (
    dict(file="howmuch-ulsan-bukgu-20260831.xlsx", sha="19826e4f5440f5df10f805bab8aaeb8cd0ce5c00af34c711b649cbec2c68782d",
         count=39, provider="울산광역시 북구 착한가격업소", date="2026-08-31",
         url="https://www.bukgu.ulsan.kr/lay1/S1T229C445/contents.do"),
    dict(file="howmuch-cheorwon-official", sha="8e939f86a10ce8ef55cfc3ebf0231c311ce17ee8587cda74720b14d87ffaf4f8",
         count=22, provider="강원특별자치도 철원군 착한가격업소", date="2026-06-22",
         url="https://www.cwg.go.kr/www/contents.do?key=360"),
    dict(file="howmuch-jindo-official", sha="d9f4195cf4b3c6c32a627259ec8d47e4506b70aa4e90ff38f721bbbf37423949",
         count=16, provider="전라남도 진도군 착한가격업소", date="2026-01-01",
         url="https://www.jindo.go.kr/home/sub.cs?m=243"),
    # Only entries carrying the 2025-11-17 photo date are included. Other
    # entries on the 2026-updated page carry older or undated evidence.
    dict(file="howmuch-mokpo-official", sha="d4682cd496492b09be8e32283898d919c8be71a556be3bafa96376d9439ef3ff",
         count=20, provider="전라남도 목포시 착한가격업소", date="2025-11-17",
         url="https://biz.mokpo.go.kr/www/life_welfare/industry_economy/regional_economy/good_price"),
)


def matcher():
    spec = importlib.util.spec_from_file_location("goodprice_matcher", ROOT / "scripts/expand-store-details-from-goodprice.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def plain(value):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]*>", " ", value))).strip()


def parse_xlsx(raw):
    import io
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
        shared = ["".join(item.itertext()) for item in ET.fromstring(archive.read("xl/sharedStrings.xml"))]
        sheet = ET.fromstring(archive.read("xl/worksheets/sheet1.xml"))
        rows = []
        for row in sheet.findall(".//m:sheetData/m:row", ns):
            if int(row.attrib["r"]) < 5:
                continue
            values = {}
            for cell in row.findall("m:c", ns):
                cell_value = cell.find("m:v", ns)
                if cell_value is None:
                    continue
                column = re.match(r"[A-Z]+", cell.attrib["r"]).group()
                values[column] = (shared[int(cell_value.text)] if cell.attrib.get("t") == "s"
                                  else cell_value.text)
            if values.get("A"):
                rows.append((values["A"].strip(), values.get("B", "").strip(),
                             values.get("C", "").strip(), values.get("F", "").strip()))
        return rows


def parse_cheorwon(raw):
    page = raw.decode("utf-8").split('<div class="cts360_wrap">', 1)[1]
    rows = []
    for tr in re.findall(r"<tr[^>]*>(.*?)</tr>", page, re.S):
        cells = [plain(cell) for cell in re.findall(r"<td[^>]*>(.*?)</td>", tr, re.S)]
        if len(cells) == 8:
            rows.append((cells[0], cells[2], cells[3], cells[5]))
    return rows


def parse_jindo(raw):
    page = raw.decode("utf-8").split('<div class="goodPrice">', 1)[1]
    rows = []
    for item in re.findall(r"<li[^>]*>(.*?)</li>", page, re.S):
        name = re.search(r'<p class="tit">(.*?)</p>', item, re.S)
        address = re.search(r'<p class="addr">(.*?)</p>', item, re.S)
        if not name or not address:
            continue
        parts = [plain(part) for part in re.split(r"<br\s*/?>", address.group(1)) if plain(part)]
        phone = next((part for part in parts if re.fullmatch(r"0\d{1,3}-\d{3,4}-\d{4}", part)), "")
        hours = next((part.split(":", 1)[1].strip() for part in parts if part.startswith("영업시간:")), "")
        rows.append((plain(name.group(1)), parts[0], phone, hours))
    return rows


def parse_mokpo(raw):
    page = raw.decode("utf-8")
    rows = []
    for item in re.finditer(r"<h4>(.*?)</h4>(.*?)(?=<h4>|<dt class=\"update\")", page, re.S):
        section = item.group(2)
        if "price_251117_" not in section:
            continue
        address = re.search(r"<li>소재지\s*:\s*(.*?)</li>", section, re.S)
        phone = re.search(r"<li>연락처\s*:\s*(.*?)</li>", section, re.S)
        hours = re.search(r"<li>영업시간\s*:\s*(.*?)</li>", section, re.S)
        if address:
            rows.append((plain(item.group(1)), plain(address.group(1)),
                         plain(phone.group(1)) if phone else "", plain(hours.group(1)) if hours else ""))
    return rows


def valid_hours(value):
    times = re.findall(r"(?<!\d)(\d{1,2}):(\d{2})(?!\d)", value)
    if not times and value != "24시간":
        return False
    return all(int(hour) < 24 or (int(hour) == 24 and int(minute) == 0)
               for hour, minute in times) and all(int(minute) < 60 for _, minute in times)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    store_path = ROOT / "howmuch_backend/src/main/resources/stores-snapshot.json"
    catalog_path = ROOT / "howmuch_backend/src/main/resources/store-hours.json"
    stores = json.loads(store_path.read_text(encoding="utf-8"))
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    by_id = {entry["storeId"]: entry for entry in catalog}
    match = matcher()
    by_name_and_building = defaultdict(list)
    for store in stores:
        building = match.building_key(store["address"])
        if building:
            by_name_and_building[(match.name_key(store["storeName"]), building)].append(store)
    summaries = []
    parsers = (parse_xlsx, parse_cheorwon, parse_jindo, parse_mokpo)
    for source, parse in zip(SOURCES, parsers):
        raw = (args.source_dir / source["file"]).read_bytes()
        if hashlib.sha256(raw).hexdigest() != source["sha"]:
            raise ValueError(f"Official source changed: {source['file']}")
        rows = parse(raw)
        if len(rows) != source["count"]:
            raise ValueError(f"Unexpected row count: {source['file']} ({len(rows)})")
        source_keys = Counter((match.name_key(name), match.building_key(address))
                              for name, address, _, _ in rows)
        counts = Counter()
        for name, address, phone, hours in rows:
            key = (match.name_key(name), match.building_key(address))
            candidates = by_name_and_building.get(key, [])
            if not key[0] or not key[1] or source_keys[key] != 1 or len(candidates) != 1:
                counts["unmatched"] += 1
                continue
            store = candidates[0]
            source_phone = match.phone_key(phone)
            store_phone = match.phone_key(store.get("phoneNumber"))
            if source_phone and store_phone and source_phone != store_phone:
                counts["phoneConflict"] += 1
                continue
            if not valid_hours(hours):
                counts["invalidHours"] += 1
                continue
            store_id = match.store_id(store)
            entry = by_id.get(store_id)
            if entry is None:
                entry = dict(storeId=store_id, storeName=store["storeName"], address=store["address"],
                             phoneNumber=store.get("phoneNumber"), status="SOURCE_VERIFIED",
                             text=NO_HOURS, sourceName=source["provider"], sourceUrl=source["url"],
                             checkedAt=source["date"], parkingYn=None, packingYn=None,
                             areaCurrency=None, imageUrls=[])
                catalog.append(entry)
                by_id[store_id] = entry
                counts["newCatalogEntry"] += 1
            if entry["text"] != NO_HOURS:
                counts["alreadyHasHours"] += 1
                continue
            entry.update(text=hours, sourceName=source["provider"], sourceUrl=source["url"],
                         checkedAt=source["date"])
            counts["added"] += 1
        summaries.append({"source": source["provider"], "sourceRows": len(rows), **counts})
    print(json.dumps(summaries, ensure_ascii=False, indent=2))
    if args.write:
        catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
