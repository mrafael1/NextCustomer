"""Per-aisle review sheets for the capsule tiers (#58, #89) and the #59 icons, built from the PNGs
in art/ (run tools/pixel_art.py build first). From the repo root:

    python docs/art/review/review_sheets_src/review_sheets.py

writes docs/art/review/capsule_tiers_<aisle>.png (each capsule product of the aisle on a band:
plain, BIG and GOLDEN at 3x, the mini and its golden copy at 8x and 1x, then the three sprites at
1x in colour and greyscale) and icons_59.png (the six coupon icons over the slip at 4x, then the
perk icons at 8x and 2x, Big basket's plus_slot beside Extra coupon slot's icon)."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools"))
import pixel_art as pa  # noqa: E402

CREAM = (0xF2, 0xE8, 0xD5, 255)
TEAL = (0x5E, 0x8C, 0x87, 255)
OUT = ROOT / "docs/art/review"


def load(rel: str):
    return pa.decode_png((ROOT / rel).read_bytes())


def over(bg, grid):
    """grid composited over a solid colour (alpha 0 -> bg)."""
    return [[px if px[3] else bg for px in row] for row in grid]


def capsules_by_aisle():
    found = {}
    for f in sorted((ROOT / "data/aisles").glob("*.tres")):
        text = f.read_text(encoding="utf-8")
        aisle = re.search(r'^id = &"(\w+)"', text, re.M).group(1)
        paths = dict(re.findall(r'path="res://data/cards/(\w+)\.tres" id="([^"]+)"', text))
        ids = {v: k for k, v in paths.items()}
        m = re.search(r"^capsule_cards = .*$", text, re.M)
        if not m:
            continue
        refs = re.findall(r'ExtResource\("([^"]+)"\)', m.group(0))
        cards = [ids[r] for r in refs if r in ids]
        if cards:
            found[aisle] = cards
    return found


def aisle_sheet(aisle: str, cards: list[str]) -> Path:
    s = 3
    cell = 48 * s + 8
    mini = 7 * 8
    width = 8 + 3 * cell + 2 * (mini + 8) + 8 + 3 * 52 + 8
    height = 8 + len(cards) * (cell + 4) + 8
    sheet = pa.blank(width, height, CREAM)
    for row, card in enumerate(cards):
        y = 8 + row * (cell + 4)
        bg = CREAM if row % 2 == 0 else TEAL
        band = pa.blank(width - 8, cell, bg)
        pa.paste(sheet, band, 4, y - 4)
        for col, suffix in enumerate(["", "_big", "_golden"]):
            grid = over(bg, load(f"art/items_v2/{card}{suffix}.png"))
            pa.paste(sheet, pa.scale_grid(grid, s), 8 + col * cell, y)
        x = 8 + 3 * cell
        for col, suffix in enumerate(["", "_golden"]):
            grid = over(bg, load(f"art/minis/{card}{suffix}.png"))
            pa.paste(sheet, pa.scale_grid(grid, 8), x + col * (mini + 8), y + 8)
        x += 2 * (mini + 8) + 8
        for col, suffix in enumerate(["", "_big", "_golden"]):
            grid = over(bg, load(f"art/items_v2/{card}{suffix}.png"))
            pa.paste(sheet, grid, x + col * 52, y + 8)
            pa.paste(sheet, pa.greyscale(grid), x + col * 52, y + 8 + 52)
        # 1x minis under the 8x ones
        for col, suffix in enumerate(["", "_golden"]):
            grid = over(bg, load(f"art/minis/{card}{suffix}.png"))
            pa.paste(sheet, grid, 8 + 3 * cell + col * 12, y + 8 + mini + 8)
    path = OUT / f"capsule_tiers_{aisle}.png"
    path.write_bytes(pa.encode_rgba(sheet))
    return path


def icons_sheet() -> Path:
    coupons = ["repeat", "final_markdown", "breakfast_sticker", "shelf_swap", "clearance_tag", "opening_deal"]
    perks = ["perk_coupon_engine", "perk_slot_engine", "perk_extra_coupon_slot", "plus_slot"]
    slip = load("art/items_v2/coupon_slip.png")
    s = 4
    cell = 48 * s + 8
    width = 8 + 4 * cell
    height = 8 + 2 * cell + 8 + 16 * 6 + 24
    sheet = pa.blank(width, height, CREAM)
    for i, c in enumerate(coupons):
        grid = [row[:] for row in slip]
        icon = load(f"art/icons/coupon_{c}_v2.png")
        for yy, line in enumerate(icon):
            for xx, px in enumerate(line):
                if px[3]:
                    grid[19 + yy][14 + xx] = px
        grid = over(CREAM, grid)
        pa.paste(sheet, pa.scale_grid(grid, s), 8 + (i % 3) * cell, 8 + (i // 3) * cell)
    y = 8 + 2 * cell + 8
    for i, p in enumerate(perks):
        grid = over(CREAM, load(f"art/icons/{p}.png"))
        pa.paste(sheet, pa.scale_grid(grid, 8), 8 + i * cell, y)
        pa.paste(sheet, pa.scale_grid(grid, 2), 8 + i * cell + 120, y)
    path = OUT / "icons_59.png"
    path.write_bytes(pa.encode_rgba(sheet))
    return path


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for aisle, cards in capsules_by_aisle().items():
        print(aisle, cards, aisle_sheet(aisle, cards))
    print(icons_sheet())
