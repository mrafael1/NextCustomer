"""#77 prep: builds docs/art/mockups/machine_77_flow.html from flow_template.html.

Inlines, so the page is self-contained and its canvases stay untainted under file://:
- the sprites in ../assets/, the game's item sprites (art/items_v2/<id>.png, read only) and the upgrade sprites
  (../upgrades/png/items_v2/<id>.png, <id>_big.png, <id>_golden.png) as data URIs;
- the product data read from data/cards/*.tres and data/aisles/*.tres (read only) and ../product_rarity.json,
  also written to flow_data.json for check_odds.js;
- draw77.js (the one draw process);
- every looks/look_*.js and looks/look_*.css (pluggable machine looks, see looks/README.md), sorted by name.

Usage: python gen_flow.py
"""
import base64
import json
import pathlib
import re

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parent
ASSETS = SRC / "assets"
UPG = SRC / "upgrades" / "png" / "items_v2"
REPO = SRC.parents[3]
CARDS = REPO / "data" / "cards"
AISLES = REPO / "data" / "aisles"
GAME_ITEMS = REPO / "art" / "items_v2"
OUT = SRC.parent / "machine_77_flow.html"
DATA_OUT = HERE / "flow_data.json"

NAMES = [
    "coupon_slip", "art_pending_v2", "coupon_multipack_v2", "coupon_two_for_one_v2", "cart", "stamp_ring",
    "stamp_ring_empty", "warning", "menu", "sparkle", "printer_box", "printer_lip", "cashier", "register_keypad",
    "cash_drawer", "basket_front", "wall_clock",
]
UPGRADABLE = ["banana", "milk", "eggs", "coffee"]


def uri(path: pathlib.Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def parse_value(raw: str):
    raw = raw.strip()
    m = re.fullmatch(r'&?"(.*)"', raw)
    if m:
        return m.group(1)
    try:
        return int(raw)
    except ValueError:
        try:
            return float(raw)
        except ValueError:
            return raw


def parse_tres(path: pathlib.Path):
    """Sections of a .tres as (header, {field: value}); multi-line values are skipped."""
    sections, cur = [], None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("["):
            cur = (line, {})
            sections.append(cur)
            continue
        m = re.match(r"^(\w+) = (.*)$", line)
        if m and cur is not None:
            cur[1][m.group(1)] = parse_value(m.group(2))
    return sections


def read_cards():
    cards = {}
    for path in sorted(CARDS.glob("*.tres")):
        secs = parse_tres(path)
        res = next((f for h, f in secs if h.startswith("[resource")), {})
        subs = [f for h, f in secs if h.startswith("[sub_resource")]
        cards[path.stem] = (res, subs)
    names = {cid: res.get("display_name", cid) for cid, (res, _) in cards.items()}
    out = {}
    for cid, (res, subs) in cards.items():
        if res.get("kind") != 1 and "base" not in res:
            continue  # coupons have no base
        text = res.get("sticker_text") or ""

        def sub(m):
            k = m.group(1)
            if k == "name":
                return res.get("display_name", cid)
            if k == "base":
                return str(res.get("base", ""))
            for f in subs:
                if k in f:
                    v = f[k]
                    return names.get(v, v) if isinstance(v, str) else str(v)
            return m.group(0)

        line = re.sub(r"\{(\w+)\}", sub, text) if text else "No rule"
        out[cid] = {"n": res.get("display_name", cid), "base": res.get("base", 0), "line": line}
    return out


def read_aisles():
    out = {}
    for path in sorted(AISLES.glob("*.tres")):
        text = path.read_text(encoding="utf-8")
        items = re.findall(r'path="res://data/cards/(\w+)\.tres"', text)
        name = re.search(r'display_name = "([^"]+)"', text).group(1)
        out[path.stem] = {"n": name, "items": items}
    return out


def mc_text() -> str:
    """The odds check's summary for the caption, from check_odds.js's last run."""
    res = HERE / "check_odds_result.json"
    if not res.exists():
        return "not run yet: node check_odds.js"
    r = json.loads(res.read_text(encoding="utf-8"))
    return (f"last run: {r['states']} states, {r['rolls']:,} rolls each, largest gap "
            f"{r['max_dev_points']:.2f} points ({r['max_dev_where']}); that is {r['max_z']:.1f} standard errors, "
            f"sampling noise over the printed numbers"
            + (f"; {r['bonus_states']} of them are BONUS TICKET states, largest gap {r['bonus_max_dev_points']:.2f} points"
               if r.get("bonus_states") else ""))


def main() -> None:
    rarity = json.loads((SRC / "product_rarity.json").read_text(encoding="utf-8"))
    products = read_cards()
    aisles = read_aisles()
    every = set(rarity["full_collection_stock"])
    missing = every - set(products)
    assert not missing, f"no card data for {missing}"
    data = {"products": {k: v for k, v in products.items() if k in every}, "aisles": aisles, "rarity": rarity}
    DATA_OUT.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")

    assets = {name: uri(ASSETS / f"{name}.png") for name in NAMES}
    for pid in sorted(every):
        if pid in UPGRADABLE and (UPG / f"{pid}.png").exists():
            assets[pid] = uri(UPG / f"{pid}.png")
        elif (GAME_ITEMS / f"{pid}.png").exists():
            assets[pid] = uri(GAME_ITEMS / f"{pid}.png")
        elif (ASSETS / f"{pid}.png").exists():
            assets[pid] = uri(ASSETS / f"{pid}.png")
    for pid in UPGRADABLE:
        for tier in ("big", "golden"):
            p = UPG / f"{pid}_{tier}.png"
            if p.exists():
                assets[f"{tier}_{pid}"] = uri(p)

    # each look in its own <script>, so one broken look can't stop the page (its error shows in the console)
    looks_js = "\n".join(
        f"<script>\n// ---- looks/{p.name}\n" + p.read_text(encoding="utf-8").replace("</script", "<\\/script") + "\n</script>"
        for p in sorted((HERE / "looks").glob("look_*.js")))
    looks_css = "\n".join(f"/* ---- {p.name} */\n" + p.read_text(encoding="utf-8") for p in sorted((HERE / "looks").glob("look_*.css")))

    page = (HERE / "flow_template.html").read_text(encoding="utf-8")
    for marker, value in [
        ("/*@@ASSETS@@*/", "const ASSET = " + json.dumps(assets) + ";"),
        ("/*@@DATA@@*/", "const DATA = " + json.dumps(data, ensure_ascii=False) + ";"),
        ("/*@@DRAW@@*/", (HERE / "draw77.js").read_text(encoding="utf-8")),
        ("<!--@@LOOKS_JS@@-->", looks_js),
        ("@@MC@@", mc_text()),
        ("/*@@LOOKS_CSS@@*/", looks_css),
    ]:
        assert marker in page, marker
        page = page.replace(marker, value)
    OUT.write_text(page, encoding="utf-8", newline="\n")
    print(f"wrote {OUT} ({len(page) // 1024} KB), {DATA_OUT.name}; looks inlined: "
          + (", ".join(p.name for p in sorted((HERE / "looks").glob("look_*.*"))) or "none"))


if __name__ == "__main__":
    main()
