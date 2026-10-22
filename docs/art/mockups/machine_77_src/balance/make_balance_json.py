"""Writes machine_77_src/balance.json (the loyalty page's balance sketch) from analyze.py's output.
usage: python make_balance_json.py ANALYZED.json [MORE_ANALYZED.json ...]  (later files add or override keys)
"""
import json
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "balance.json"
CURVE_A = [37, 38, 40, 46, 47, 53, 54, 63]
LIVE = [34, 35, 53, 61, 73, 98, 111, 120]

# (key, group, label, sub, note)
ROWS = [
    ("today", "NOW", "Today (kiosk 2/4/6, free)", "kiosk after 2/4/6, free", "3 registers on top of 7 rewards; every offer guarantees one that fits"),
    ("r0", "FLOOR", "R0: no register power", "R0", "the floor option A is built on"),
    ("r1", "", "R1: 1 free (after 4)", "R1: after shift 4", "B-pity's floor, free"),
    ("r2", "", "R2: 2 free (after 2, 4)", "R2: after 2 and 4", "free"),
    ("a_rand", "OPTION A", "REGISTER blind, 30% visits", "30% of visits, costs the item", "no floor; picks blind, as a player who sees only the odds"),
    ("a_greedy", "", "REGISTER when best*", "greedy, costs the item", "no floor; this player sees the 3 prizes before choosing (optimistic)"),
    ("b_stamp_only", "OPTION B", "STAMP DAY only", "never picks REGISTER", "free stamps after 2/4/6 at machine rarity odds; no fits/types guarantee"),
    ("b_stamp_fits", "", "STAMP DAY only + fits", "never picks REGISTER", "as above, plus the 'one fits your cart' guarantee, swapped within the rolled tier (fix pass)"),
    ("b_rand_floor", "", "STAMP DAY + blind 30%", "30% of visits", "blind REGISTER picks, STAMP DAY tops up"),
    ("b_floor", "", "STAMP DAY + greedy*", "REGISTER when best", "optimistic: sees the prizes before choosing"),
    ("b_pity", "", "B-pity: >=1 by shift 4*", ">=1 by shift 4 + greedy", "optimistic, like the row above"),
    ("today_items", "+ ITEM UPGRADES", "Today + item upgr.*", "UPGRADES after 3/5/7", "optimistic: compares the rolled UPGRADES drops with the reward before choosing; NEW ITEMS meter shared with COUPONS (BIG/GOLDEN arrivals overstated)"),
    ("b_stamp_items_blind", "", "STAMP DAY + upgr. (blind)", "never picks REGISTER", "UPGRADES taken whenever open, before seeing the drops; NEW ITEMS meter rises only on product picks (fix pass)"),
    ("b_stamp_items", "", "STAMP DAY + item upgr.*", "never picks REGISTER", "optimistic: sees the UPGRADES drops first; NEW ITEMS meter shared with COUPONS (overstated)"),
    ("b_items", "", "STAMP DAY + greedy* + upgr.", "REGISTER when best", "optimistic"),
    ("split_blind", "ROUND 2: CLEAN SPLIT", "STAMP DAY + split (blind)", "never picks REGISTER", "NEW ITEMS: plain products by product rarity; UPGRADES after 3/5/7 taken whenever open (one step / two steps / shelf upgrade)"),
    ("split_breakfast", "", "Same, Breakfast build", "build:breakfast_special", "the #42 viability check: needs 2/3 of greedy"),
    ("prodrarity_only", "", "STAMP DAY + product rarity", "no UPGRADES", "NEW ITEMS by product rarity, no item upgrades: the product-rarity effect alone"),
    ("bonus_greedy", "ROUND 3: INSPECTION BONUS TICKET", "R3a: split + bonus ticket", "never picks REGISTER", "as round 2's split row, plus a second machine visit after each passed inspected shift (3/5/7): UPGRADES again if a copy can step, else NEW ITEMS/COUPONS"),
    ("bonus_rare", "", "R3b: + Carrier bag, Tea bags Rare", "never picks REGISTER", "R3a with Carrier bag and Tea bags moved from Legendary to Rare in the product rarity table"),
    ("bonus_breakfast", "", "R3c: R3a, Breakfast build", "build:breakfast_special", "the #42 viability check on R3a: needs 2/3 of R3a's greedy rate"),
    ("bonus_rare_s1", "", "R3e: R3b + bonus after shift 1", "never picks REGISTER", "R3b plus a free second visit after shift 1 (NEW ITEMS/COUPONS; UPGRADES is not open yet)"),
]

HIDDEN = {"r1", "r2", "b_pity", "today_items", "b_items"}


def skip_line(data):
    t, r = data.get("today_skip"), data.get("r0_skip")
    if not t or not r:
        return ""
    return (f"<b>skip@sensible</b> (skips every reward; live / A quotas): today {t['live']:.0%} / {t['a']:.0%}, "
            f"no registers {r['live']:.0%} / {r['a']:.0%} ({t['runs']} runs each)")


def main():
    data = {}
    for name in sys.argv[1:]:
        data.update(json.loads(Path(name).read_text(encoding="utf-8")))
    scenarios = []
    for key, group, label, sub, note in ROWS:
        d = data.get(key)
        scenarios.append({
            "key": key, "group": group, "label": label, "sub": sub, "note": note,
            "live": round(d["live"], 4) if d else None,
            "a": round(d["a"], 4) if d and "a" in d else None,
            "n": d["runs"] if d else 0,
        })
    # Round 3 (2026-10-20): the chart has room for 18 rows, so five superseded round-1 rows stay in
    # balance.json but are hidden on the chart; a hidden row's group label moves to the next shown row.
    carry = ""
    for row in scenarios:
        row["hidden"] = row["key"] in HIDDEN
        if row["hidden"]:
            carry = carry or row["group"]
            row["group"] = ""
        elif carry and not row["group"]:
            row["group"], carry = carry, ""
        else:
            carry = ""
    verdicts = json.loads((Path(__file__).resolve().parent / "verdicts.json").read_text(encoding="utf-8"))
    out = {
        "subtitle": "greedy@sensible · * sees the prizes first (upper bound)",
        "skip": skip_line(data),
        "scenarios": scenarios,
        "curves": {"live": LIVE, "a": CURVE_A},
        "verdicts": verdicts,
    }
    OUT.write_text(json.dumps(out, indent=1), encoding="utf-8", newline="\n")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
