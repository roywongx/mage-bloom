#!/usr/bin/env python3
"""Extract offline REA data into data/*.json.

Inputs (local analysis workspace, not shipped):
  - Data_SpellBook.lua from DungeonsForeverSpell
  - LiuyueForever decoded SpellBook / SpellDuration / APL
  - MageProbe.json (client probe, build 1.60.1.70959)
  - TitanForever Core.lua (control block schema)
  - SAO mage.lua (proc IDs)

Outputs: data/client, data/spells, data/auras, data/liuyue, data/titanforever, data/sao
No third-party source code is copied; only derived factual tables.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.environ.get("REA_SRC", "/home/roy/wow-addon-re")
OUT = os.path.join(ROOT, "data")

def read(p):
    return open(p, encoding="utf-8", errors="surrogateescape").read()

def match_brace(s, i):
    depth = 0
    while i < len(s):
        if s[i] == "{": depth += 1
        elif s[i] == "}":
            depth -= 1
            if depth == 0: return i
        i += 1
    return -1

def split_top(s):
    """Split a Lua table body into top-level {...} entries."""
    out, depth, start = [], 0, None
    for i, ch in enumerate(s):
        if ch == "{":
            if depth == 0: start = i
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0 and start is not None:
                out.append(s[start:i+1]); start = None
    return out

def parse_dfspell():
    p = os.path.join(SRC, "forever/Data_SpellBook.lua")
    s = read(p)
    k = s.find("MAGE = {")
    if k < 0: raise SystemExit("mage class not found")
    start = s.find("{", k)
    end = match_brace(s, start)
    block = s[start:end+1]
    ti = block.find("tabs = {")
    ts = block.find("{", ti)
    te = match_brace(block, ts)
    entries = []
    for tab in split_top(block[ts+1:te]):
        tabname = re.search(r'name\s*=\s*"([^"]+)"', tab)
        tabname = tabname.group(1) if tabname else ""
        sp = tab.find("spells = {")
        if sp < 0: continue
        sp_start = tab.find("{", sp)
        sp_end = match_brace(tab, sp_start)
        for e in split_top(tab[sp_start+1:sp_end]):
            e = e[:-1] + ', tab = "%s" }' % tabname
            entries.append(e)
    out = []
    for e in entries:
        name = re.search(r'name\s*=\s*"([^"]+)"', e)
        if not name: continue
        rec = {"name": name.group(1)}
        for f in ("id", "learnLv"):
            m = re.search(f + r'\s*=\s*(\d+)', e)
            if m: rec[f] = int(m.group(1))
        if "isTalent = true" in e: rec["isTalent"] = True
        ranks = []
        rm = re.search(r'ranks\s*=\s*\{', e)
        if rm:
            rs = rm.end() - 1
            re_end = match_brace(e, rs)
            for r in split_top(e[rs+1:re_end]):
                rr = {}
                for f in ("rank", "learn", "id"):
                    m = re.search(f + r'\s*=\s*(\d+)', r)
                    if m: rr[f] = int(m.group(1))
                if rr: ranks.append(rr)
        m = re.search(r'tab\s*=\s*"([^"]*)"', e)
        if m: rec["tab"] = m.group(1)
        if ranks: rec["ranks"] = ranks
        out.append(rec)
    return out

def parse_liuyue_spellbook():
    p = os.path.join(SRC, "forever/spellbook_mage.txt")
    s = read(p)
    out = {}
    for line in s.splitlines():
        m = re.match(r'\s*\["([^"]+)"\]\s*=\s*\{\s*learnLv\s*=\s*(\d+),\s*ids\s*=\s*\{([^}]*)\},\s*lvs\s*=\s*\{([^}]*)\}', line)
        if not m: continue
        name, lv = m.group(1), int(m.group(2))
        ids = [int(x) for x in re.findall(r'\d+', m.group(3))]
        lvs = [int(x) for x in re.findall(r'\d+', m.group(4))]
        out[name] = {"name": name, "learnLv": lv, "ids": ids, "lvs": lvs}
    return out

def parse_liuyue_durations():
    p = os.path.join(SRC, "dec/LiuyueForever/Core/SpellDuration.lua")
    s = read(p)
    out = {}
    for m in re.finditer(r'SpellDurByName\["([^"]+)"\]\s*=\s*([0-9.]+)', s):
        out[m.group(1)] = float(m.group(2))
    return out

def parse_liuyue_apl():
    p = os.path.join(SRC, "dec/LiuyueForever/Core/APL.lua")
    s = read(p)
    def block(start_pat):
        i = s.find(start_pat)
        if i < 0: return ""
        j = s.find("{", i); e = match_brace(s, j)
        return s[j:e+1]
    out = {
        "data": block("A.DATA = {"),
        "leveling": block("A.LEVELING_SPEC_CHAINS = {"),
        "extra": block("local EXTRA = {"),
    }
    # only mage slice
    for k, v in list(out.items()):
        i = v.find("MAGE = {")
        if i >= 0:
            j = v.find("{", i); e = match_brace(v, j)
            out[k] = v[i:e+1]
    return out

def parse_probe():
    p = os.path.join(SRC, "forever/MageProbe.json")
    return json.load(open(p, encoding="utf-8"))

def build_spells(df, ly, probe):
    merged = {}
    for rec in df:
        n = rec["name"]
        row = merged.setdefault(n, {"name": n, "ids": [], "ranks": [], "sources": []})
        if rec.get("id"): row["ids"].append(rec["id"])
        if rec.get("learnLv"): row["learnLv"] = rec["learnLv"]
        if rec.get("ranks"): row["ranks"] = rec["ranks"]
        if rec.get("isTalent"): row["isTalent"] = True
        row["sources"].append("dfspell")
    for n, rec in ly.items():
        row = merged.setdefault(n, {"name": n, "ids": [], "ranks": [], "sources": []})
        for i in rec["ids"]:
            if i not in row["ids"]: row["ids"].append(i)
        row.setdefault("learnLv", rec["learnLv"])
        row["liuyue"] = {"ids": rec["ids"], "lvs": rec["lvs"]}
        if "liuyue" not in row["sources"]: row["sources"].append("liuyue")
    spells = probe.get("spells") or {}
    by_id = {}
    for k, v in spells.items():
        try: by_id[int(k)] = v
        except Exception: pass
    for n, row in merged.items():
        # best probe record: exact name, prefer known / highest id
        cands = [v for v in by_id.values() if v.get("name") == n]
        if cands:
            cands.sort(key=lambda v: (bool(v.get("known")), v.get("spellID") or 0), reverse=True)
            v = cands[0]
            row["probe"] = {"id": v.get("spellID"), "known": v.get("known"),
                            "castTime": v.get("castTime"), "description": v.get("description")}
            if "probe" not in row["sources"]: row["sources"].append("probe")
        row["ids"] = sorted(set(row["ids"]))
    return merged

def build_auras(probe):
    ids = [400624, 400625, 400669, 400670, 400588, 400589, 400573, 22959, 12579,
           1326891, 12536, 5276, 1240047, 13033, 1259705, 12042, 12043, 11129]
    spells = probe.get("spells") or {}
    out = {}
    for i in ids:
        v = spells.get(str(i)) or spells.get(i) or {}
        out[str(i)] = {
            "id": i, "name": v.get("name"), "description": v.get("description"),
            "known": v.get("known"), "castTime": v.get("castTime"),
            "tooltip": (probe.get("tooltips") or {}).get(str(i)) or (probe.get("tooltips") or {}).get(i),
        }
    return out

def build_titanforever():
    cands = [os.path.join(SRC, "wow-ah/addon-forever/TitanForever/Core.lua"),
             "/home/roy/wow-ah/addon-forever/TitanForever/Core.lua"]
    p = next((x for x in cands if os.path.exists(x)), "")
    s = read(p) if p else ""
    flags = {}
    if s:
        i = s.find("Strip.FLAGS")
        j = s.find("}", i)
        for m in re.finditer(r'(\w+)\s*=\s*0x([0-9A-Fa-f]{1,4})', s[i:j]):
            flags[m.group(1)] = "0x" + m.group(2).upper()
    return {
        "source": "wow-ah/addon-forever/TitanForever/Core.lua",
        "block": {"cols": 128, "rows": 12, "cell_px": 4, "bytes": 4608,
                  "magic": "TC01", "max_payload": 4574, "crc": "CRC16-CCITT-FALSE"},
        "flags": {k: "0x" + v for k, v in flags.items()},
        "snapshot_fields": ["at", "uptime", "money", "speed", "dead", "counts", "profession",
                            "target", "casting", "selected", "merchant", "bag_items",
                            "windows", "buttons", "recipes", "gossip", "chat_log", "answer",
                            "lastAction", "nameplates", "mouseover"],
        "notes": "Exact field set depends on Ctl.snapshot; see docs/13.",
    }

def build_sao():
    return {
        "source": "SpellActivationOverlay/classes/mage.lua (Forever branch)",
        "ids": {
            "hot_streak_buff": 400625, "hot_streak_talent": 400624,
            "fingers_of_frost_a": 400669, "fingers_of_frost_b": 400670,
            "fingers_of_frost_talent": 400647,
            "missile_barrage_buff": 400589, "missile_barrage_talent": 400588,
            "arcane_blast_buff": 400573, "ice_barrier_buff": 1326891,
            "freeze_anchor": 5276,
        },
        "conflicts": ["400669 vs 400670 both named 寒冰指 in client; listen to both.",
                      "1326891 client name is 极寒之力, likely Ice Barrier buff.",
                      "22959 client name is 痛苦诅咒, not Fire Vulnerability."],
    }

def main():
    df = parse_dfspell()
    ly = parse_liuyue_spellbook()
    probe = parse_probe()
    os.makedirs(os.path.join(OUT, "spells"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "client"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "liuyue"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "auras"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "titanforever"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "sao"), exist_ok=True)

    json.dump(probe, open(os.path.join(OUT, "client/mageprobe_1.60.1.70959.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(build_spells(df, ly, probe), open(os.path.join(OUT, "spells/mage_spells.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump({"spells": df}, open(os.path.join(OUT, "spells/dfspell_mage.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(ly, open(os.path.join(OUT, "liuyue/spellbook_mage.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    durs = parse_liuyue_durations()
    mage_names = set(ly.keys()) | {r["name"] for r in df}
    json.dump({k: v for k, v in durs.items() if k in mage_names},
              open(os.path.join(OUT, "liuyue/durations.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    # known spells / estimated level from the client probe
    known = []
    for k, v in (probe.get("spells") or {}).items():
        if v.get("known"):
            known.append({"id": int(k), "name": v.get("name"), "castTime": v.get("castTime"),
                          "description": v.get("description")})
    json.dump({"source": "MageProbe 1.60.1.70959", "known": sorted(known, key=lambda x: x["id"])},
              open(os.path.join(OUT, "client/known_spells.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    # liuyue extras from the earlier extraction
    rawp = os.path.join(SRC, "forever/liuyue_mage_raw.json")
    if os.path.exists(rawp):
        raw = json.load(open(rawp, encoding="utf-8"))
        for k in ("talents", "gear", "tips", "voice"):
            if k in raw:
                json.dump({k: raw[k]}, open(os.path.join(OUT, "liuyue", k + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(parse_liuyue_apl(), open(os.path.join(OUT, "liuyue/apl_mage.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(build_auras(probe), open(os.path.join(OUT, "auras/procs.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(build_titanforever(), open(os.path.join(OUT, "titanforever/control_schema.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump(build_sao(), open(os.path.join(OUT, "sao/proc_ids.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("wrote", OUT)

if __name__ == "__main__":
    main()
