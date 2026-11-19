#!/usr/bin/env python3
"""Fetch authoritative Forever spell data and filter it to the mage set.

Sources:
  1. Wago Tools DB2 export: https://wago.tools/db2/Spell/csv?build=1.60.1.70959
  2. Wowhead tooltip API:   https://nether.wowhead.com/tooltip/spell/<id>?dataEnv=4&locale=4
  3. wowsims/gamedata:      spells/mage/*.txt (facts extracted by hand into data/spells/gamedata_mage_facts.json)

Writes:
  data/client/spell_db_mage_1.60.1.70959.csv
  data/auras/wowhead_tooltips.json
"""
import csv, io, json, os, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = "1.60.1.70959"
EXTRA = [400647, 400669, 400670, 22959, 1326891, 400625, 400573, 400589,
         1240047, 13033, 12536, 12579, 12042, 12043, 11129]

def get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "MageBloom-REA/0.1"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()

def mage_ids():
    d = json.load(open(os.path.join(ROOT, "data/spells/mage_spells.json"), encoding="utf-8"))
    ids = set()
    for row in d.values():
        ids.update(int(x) for x in row.get("ids") or [])
    ids.update(EXTRA)
    return ids

def main():
    ids = mage_ids()
    raw = get(f"https://wago.tools/db2/Spell/csv?build={BUILD}")
    rows = list(csv.DictReader(io.StringIO(raw.decode("utf-8"))))
    keep = [r for r in rows if r.get("ID") and int(r["ID"]) in ids]
    out = os.path.join(ROOT, "data/client/spell_db_mage_1.60.1.70959.csv")
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=rows[0].keys())
        w.writeheader(); w.writerows(keep)
    print("csv rows", len(keep), "->", out)

    tips = {}
    for i in EXTRA:
        try:
            tips[str(i)] = json.loads(get(f"https://nether.wowhead.com/tooltip/spell/{i}?dataEnv=4&locale=4").decode("utf-8"))
        except Exception as e:
            tips[str(i)] = {"error": str(e)}
    json.dump(tips, open(os.path.join(ROOT, "data/auras/wowhead_tooltips.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("tooltips", len(tips))

if __name__ == "__main__":
    main()
