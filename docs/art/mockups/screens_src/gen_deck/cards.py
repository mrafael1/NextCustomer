"""Reads the real card, upgrade, inspection and aisle data from data/ (repo-relative) for the
#56 deck-view mock-ups, so every string on the pages comes from the game's own resources.
Mirrors core/card_text.gd (sticker summaries), core/deck_summary.gd (view order, tag counts)
and core/run_stock.gd (stock order) closely enough for a mock-up; it is not a test oracle."""
import pathlib
import re

REPO = pathlib.Path(__file__).resolve().parents[5]
DATA = REPO / "data"
RULE_KEYS = ["bonus", "bonus_each", "factor", "tag", "match_value"]
TYPE_LABELS = {1: "Rule Bender", 2: "Slot Engine", 3: "Category Engine", 4: "Coupon Engine",
               5: "Economy", 6: "Risky"}


def _value(raw):
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1]
    if raw.startswith('&"'):
        return raw[2:-1]
    m = re.match(r'PackedStringArray\((.*)\)$', raw)
    if m:
        return re.findall(r'"([^"]*)"', m.group(1))
    if re.fullmatch(r'-?\d+', raw):
        return int(raw)
    if raw in ("true", "false"):
        return raw == "true"
    return raw


def parse_tres(path):
    """Returns (resource fields, [sub-resource field dicts in file order], ext ids -> paths)."""
    sections, current = [], None
    ext = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("[ext_resource"):
            p = re.search(r'path="([^"]+)"', line).group(1)
            i = re.search(r'id="([^"]+)"', line).group(1)
            ext[i] = p
            continue
        if line.startswith("["):
            current = {"__kind": line}
            sections.append(current)
            continue
        if current is not None and " = " in line:
            k, v = line.split(" = ", 1)
            current[k.strip()] = _value(v)
    res = next(s for s in sections if s["__kind"].startswith("[resource"))
    subs = [s for s in sections if s["__kind"].startswith("[sub_resource")]
    return res, subs, ext


def _card_paths(raw, ext):
    return [ext[i] for i in re.findall(r'ExtResource\("([^"]+)"\)', raw) if ext[i].startswith("res://data/cards/")]


class Card:
    def __init__(self, cid):
        res, subs, _ = parse_tres(DATA / "cards" / f"{cid}.tres")
        self.id = cid
        self.name = res["display_name"]
        self.kind = res.get("kind", 1)
        self.base = res.get("base", 0)
        self.tags = res.get("tags", [])
        template = res.get("sticker_text", "")
        values = {"base": self.base, "name": self.name}
        for sub in subs:
            for k in RULE_KEYS:
                if k in sub and k not in values:
                    values[k] = sub[k]
            if sub.get("bonus_is_base"):
                values["bonus"] = self.base
        self.summary = re.sub(r"\{(\w+)\}", lambda m: str(values.get(m.group(1), m.group(0))), template)
        self.aisle = None

    @property
    def is_product(self):
        return self.kind == 1


def aisles():
    """Aisle display names, sign colours and their card ids, in data order (balance.tres)."""
    found = []
    bal, _, bal_ext = parse_tres(DATA / "balance" / "balance.tres")
    order = [bal_ext[i] for i in re.findall(r'ExtResource\("([^"]+)"\)', str(bal["aisles"])) if bal_ext[i].startswith("res://data/aisles/")]
    for res_path in order:
        path = DATA / "aisles" / pathlib.Path(res_path).name
        res, _, ext = parse_tres(path)
        base = [pathlib.Path(p).stem for p in _card_paths(str(res.get("base_cards", "")), ext)]
        caps = [pathlib.Path(p).stem for p in _card_paths(str(res.get("capsule_cards", "")), ext)]
        found.append({"id": path.stem, "name": res["display_name"], "base": base, "capsule": caps})
    return found


_CACHE = {}


def card(cid):
    if cid not in _CACHE:
        c = Card(cid)
        for a in aisles():
            if cid in a["base"] or cid in a["capsule"]:
                c.aisle = a["id"]
        _CACHE[cid] = c
    return _CACHE[cid]


def view_key(c):
    return (0 if c.is_product else 1, c.name, c.id)


def starter_ids():
    res, _, ext = parse_tres(DATA / "decks" / "starter.tres")
    return [pathlib.Path(p).stem for p in _card_paths(str(res["cards"]), ext)]


def groups(ids):
    """[(card, copies)] in view order."""
    counts = {}
    for i in ids:
        counts[i] = counts.get(i, 0) + 1
    cards = sorted((card(i) for i in counts), key=view_key)
    return [(c, counts[c.id]) for c in cards]


def tag_counts(ids):
    counts = {}
    for i in ids:
        for t in card(i).tags:
            counts[t] = counts.get(t, 0) + 1
    return sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))


def coupon_pool():
    res, _, ext = parse_tres(DATA / "balance" / "balance.tres")
    return [pathlib.Path(p).stem for p in _card_paths(str(res["coupon_pool"]), ext)]


def stock(aisle_ids, arrivals):
    """Staples, the listed aisles' base items, the new arrivals, then the coupon pool (RunStock)."""
    ids = []
    for i in starter_ids():
        if card(i).is_product and i not in ids:
            ids.append(i)
    for a in aisles():
        if a["id"] in aisle_ids:
            ids += [i for i in a["base"] if i not in ids]
    ids += [i for i in arrivals if i not in ids]
    ids += [i for i in coupon_pool() if i not in ids]
    return sorted((card(i) for i in ids), key=view_key)


def upgrade(uid):
    res, _, _ = parse_tres(DATA / "upgrades" / f"{uid}.tres")
    return {"name": res["display_name"], "type": TYPE_LABELS[res["type"]],
            "effect": res["effect_text"], "condition": res.get("condition_text", "")}


def inspection(iid):
    res, _, _ = parse_tres(DATA / "inspections" / f"{iid}.tres")
    return {"name": res["display_name"], "notice": res["notice_text"]}


def aisle_name(aid):
    return next(a["name"] for a in aisles() if a["id"] == aid)


if __name__ == "__main__":
    print(starter_ids())
    for c, n in groups(starter_ids()):
        print(c.name, n, c.base, repr(c.summary), c.aisle)
    print(tag_counts(starter_ids()))
    for c in stock(["cold_cases", "pantry", "household"], ["cream", "sugar_cubes"]):
        print(" ", c.name, c.kind, c.base, repr(c.summary), c.aisle)
