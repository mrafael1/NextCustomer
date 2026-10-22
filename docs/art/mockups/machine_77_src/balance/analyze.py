"""#77 balance sketch: evaluates the --quotas=0 records of each scenario under a curve.
usage: python analyze.py RECORDS_DIR CURVE_A(comma list or '') OUT_JSON name[:file_prefix] ...
"""
import json
import math
import sys
from collections import Counter
from pathlib import Path

LIVE = [34, 35, 53, 61, 73, 98, 111, 120]


def raised(base, percent):
    return math.ceil(base * (100 + percent) / 100.0) if percent > 0 else base


def won(run, curve, pct):
    percent = 0
    shifts = run["shifts"]
    for i, base in enumerate(curve):
        if i >= len(shifts):
            return None  # cut short (should not happen with quotas 0)
        if shifts[i]["total"] < raised(base, percent):
            return False
        percent += pct.get(shifts[i]["upgrade_taken"], 0)
    return True


def passed_shifts(run, curve, pct):
    percent = 0
    for i, base in enumerate(curve):
        if run["shifts"][i]["total"] < raised(base, percent):
            return i
        percent += pct.get(run["shifts"][i]["upgrade_taken"], 0)
    return len(curve)


def main():
    folder = Path(sys.argv[1])
    curve_a = [int(x) for x in sys.argv[2].split(",")] if sys.argv[2] else None
    out = {}
    for spec in sys.argv[4:]:
        name, _, prefix = spec.partition(":")
        prefix = prefix or name
        files = sorted(folder.glob(f"{prefix}_records.json")) + sorted(folder.glob(f"{prefix}_b2_records.json"))
        runs = []
        pct = {}
        seen = set()
        for f in files:
            d = json.loads(f.read_text(encoding="utf-8"))
            pct = d["upgrade_quota_percent"]
            for key, rs in d["scenarios"].items():
                for r in rs:
                    if (key, r["run_seed"]) in seen:
                        continue
                    seen.add((key, r["run_seed"]))
                    runs.append(r)
        if not runs:
            continue
        n = len(runs)
        live = sum(1 for r in runs if won(r, LIVE, pct)) / n
        res = {"runs": n, "files": [f.name for f in files], "live": live}
        if curve_a:
            res["a"] = sum(1 for r in runs if won(r, curve_a, pct)) / n
        # per-shift pass rates under live
        reach = [0] * 8
        ok = [0] * 8
        for r in runs:
            p = passed_shifts(r, LIVE, pct)
            for i in range(min(p + 1, 8)):
                reach[i] += 1
                if i < p:
                    ok[i] += 1
        res["live_pass"] = [round(ok[i] / reach[i], 3) if reach[i] else None for i in range(8)]
        # registers owned (over all 7 visits, quotas 0 so every run plays all)
        owned = Counter()
        by6 = Counter()
        picks = Counter()
        first = []
        for r in runs:
            ups = [s["upgrade_taken"] for s in r["shifts"] if s["upgrade_taken"]]
            owned[len(ups)] += 1
            by6[len([s for s in r["shifts"][:6] if s["upgrade_taken"]])] += 1
            for u in ups:
                picks[u] += 1
            for s in r["shifts"]:
                if s["upgrade_taken"]:
                    first.append(s["shift"])
                    break
        res["owned"] = {k: owned[k] / n for k in sorted(owned)}
        res["owned_by_shift6"] = {k: by6[k] / n for k in sorted(by6)}
        res["register_picks"] = {k: round(v / n, 3) for k, v in picks.most_common()}
        res["mean_first_register_shift"] = round(sum(first) / len(first), 2) if first else None
        # win rate by number of registers owned (live curve)
        wbo = {}
        for k in sorted(owned):
            sub = [r for r in runs if len([s for s in r["shifts"] if s["upgrade_taken"]]) == k]
            wbo[k] = [len(sub), round(sum(1 for r in sub if won(r, LIVE, pct)) / len(sub), 3)]
        res["live_win_by_owned"] = wbo
        tiers = Counter()
        for r in runs:
            for c in r["final_deck"]:
                if c.endswith("_big") or c.endswith("_golden"):
                    tiers[c] += 1
        res["upgraded_copies_per_run"] = round(sum(tiers.values()) / n, 2)
        res["upgraded_copies"] = {k: round(v / n, 3) for k, v in tiers.most_common()}
        # main build win rates (live)
        builds = Counter(r["main_build"] for r in runs)
        res["builds"] = {}
        for b, c in builds.most_common():
            sub = [r for r in runs if r["main_build"] == b]
            res["builds"][b or "(none)"] = [c, round(sum(1 for r in sub if won(r, LIVE, pct)) / c, 3)]
        # conditional win rates (live): owning an engine (by shift 6 / at all) or not
        cond = {}
        for label, upgrade, upto in (("category_engine_by_shift6", "category_engine", 6), ("slot_engine_owned", "slot_engine", 8)):
            has = [r for r in runs if any(s["upgrade_taken"] == upgrade for s in r["shifts"][:upto])]
            hasnt = [r for r in runs if r not in has]
            cond[label] = {
                "with": [len(has), round(sum(1 for r in has if won(r, LIVE, pct)) / len(has), 3) if has else None],
                "without": [len(hasnt), round(sum(1 for r in hasnt if won(r, LIVE, pct)) / len(hasnt), 3) if hasnt else None],
            }
        res["conditional_live"] = cond
        res["median_shift8"] = sorted(r["shifts"][7]["total"] for r in runs)[n // 2]
        out[name] = res
        print(f"{name:14s} n={n:4d} live={live:6.1%}" + (f" A={res['a']:6.1%}" if curve_a else "")
              + f" owned={res['owned']} first={res['mean_first_register_shift']} up={res['upgraded_copies_per_run']}")
    Path(sys.argv[3]).write_text(json.dumps(out, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
